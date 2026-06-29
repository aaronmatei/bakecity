package payments

import (
	"context"
	"errors"
	"net/http"

	"github.com/corebalt/bakecity/internal/ledger"
	"github.com/corebalt/bakecity/internal/notifications"
	"github.com/corebalt/bakecity/internal/orders"
	"github.com/corebalt/bakecity/pkg"
	"github.com/corebalt/bakecity/pkg/pspclient"
)

const webhookScope = "psp_webhook"
const payoutScope = "payout"

// pspStatusSucceeded is the terminal "paid" status a PSP reports for a
// collection, both inline (synchronous) and via webhook.
const pspStatusSucceeded = "succeeded"

// Actor identifies the authenticated caller for authorization checks.
type Actor struct {
	UserID  string
	IsAdmin bool
}

// Service implements payment business logic: escrow collection, balance
// settlement, and webhook reconciliation against the PSP, posting to the ledger
// and advancing the order state machine.
type Service struct {
	repo   *Repository
	psp    pspclient.PSPClient
	idem   *pkg.IdempotencyStore
	ledger *ledger.Service
	orders *orders.Service
	notify *notifications.Service
}

// NewService constructs a Service.
func NewService(repo *Repository, psp pspclient.PSPClient, idem *pkg.IdempotencyStore, ledgerSvc *ledger.Service, ordersSvc *orders.Service, notifySvc *notifications.Service) *Service {
	return &Service{repo: repo, psp: psp, idem: idem, ledger: ledgerSvc, orders: ordersSvc, notify: notifySvc}
}

// InitiateDeposit starts an STK push for an APPROVED order's deposit.
func (s *Service) InitiateDeposit(ctx context.Context, actor Actor, orderID, idemKey, phone string) (*Payment, error) {
	return s.initiate(ctx, actor, orderID, idemKey, phone, KindDeposit)
}

// InitiateBalance starts an STK push for a DELIVERED order's balance.
func (s *Service) InitiateBalance(ctx context.Context, actor Actor, orderID, idemKey, phone string) (*Payment, error) {
	return s.initiate(ctx, actor, orderID, idemKey, phone, KindBalance)
}

func (s *Service) initiate(ctx context.Context, actor Actor, orderID, idemKey, phone, kind string) (*Payment, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if !actor.IsAdmin && actor.UserID != order.CustomerID {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "only the customer can pay")
	}

	var amount float64
	switch kind {
	case KindDeposit:
		if order.Status != orders.StatusApproved && order.Status != orders.StatusDepositPending {
			return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "order is not awaiting a deposit")
		}
		amount = order.DepositAmount
	case KindBalance:
		if order.Status != orders.StatusDelivered {
			return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "balance is due only after delivery")
		}
		amount = order.BalanceAmount
	}
	if amount <= 0 {
		return nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation, "no "+kind+" amount due")
	}

	// Idempotent replay: a prior request with this key returns the same payment.
	if idemKey != "" {
		if existing, err := s.repo.GetByIdempotencyKey(ctx, idemKey); err == nil {
			return existing, nil
		} else if !errors.Is(err, pkg.ErrNotFound) {
			return nil, err
		}
	}

	collect := pspclient.CollectRequest{
		OrderID: orderID, Phone: phone, Amount: amount, Currency: "KES",
		Reference: orderID, IdempotencyKey: idemKey,
	}
	var res *pspclient.CollectResult
	if kind == KindDeposit {
		res, err = s.psp.Collect(ctx, collect)
	} else {
		res, err = s.psp.CollectBalance(ctx, collect)
	}
	if err != nil {
		return nil, err
	}

	payment, err := s.repo.Create(ctx, &Payment{
		OrderID: orderID, Kind: kind, PSPRef: res.PSPRef, Amount: amount,
		Status: StatusPending, IdempotencyKey: idemKey,
	})
	if errors.Is(err, pkg.ErrConflict) && idemKey != "" {
		return s.repo.GetByIdempotencyKey(ctx, idemKey) // lost a create race
	}
	if err != nil {
		return nil, err
	}

	if kind == KindDeposit {
		if err := s.orders.MarkDepositPending(ctx, orderID); err != nil {
			return nil, err
		}
	}

	// A synchronous PSP (and the dev stub) settles the collection immediately;
	// asynchronous ones return "pending" and settle later via the webhook.
	if res.Status == pspStatusSucceeded {
		if _, err := s.settleRef(ctx, res.PSPRef, pspStatusSucceeded); err != nil {
			return nil, err
		}
		if settled, err := s.repo.GetByPSPRef(ctx, res.PSPRef); err == nil {
			payment = settled
		}
	}
	return payment, nil
}

// BakerBalance reports the caller's baker ledger position (available, held in
// escrow, and total paid out). The caller must own a baker profile.
func (s *Service) BakerBalance(ctx context.Context, actor Actor) (*BalanceSummary, error) {
	bakerID, err := s.orders.BakerIDForUser(ctx, actor.UserID)
	if err != nil {
		return nil, err
	}
	if bakerID == "" {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "caller is not a baker")
	}
	available, err := s.ledger.BakerAvailableBalance(ctx, bakerID)
	if err != nil {
		return nil, err
	}
	pending, err := s.ledger.BakerPendingBalance(ctx, bakerID)
	if err != nil {
		return nil, err
	}
	paidOut, err := s.ledger.BakerPaidOut(ctx, bakerID)
	if err != nil {
		return nil, err
	}
	return &BalanceSummary{Available: available, Pending: pending, PaidOut: paidOut}, nil
}

// RequestPayout disburses the caller-baker's full available balance to their
// M-Pesa via the PSP, books the ledger debit, and records a payout. A
// per-baker reservation prevents a concurrent double-payout; once paid, the
// available balance is zero so a replay returns "no funds".
func (s *Service) RequestPayout(ctx context.Context, actor Actor, idemKey string) (*Payout, error) {
	bakerID, err := s.orders.BakerIDForUser(ctx, actor.UserID)
	if err != nil {
		return nil, err
	}
	if bakerID == "" {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "only a baker can request a payout")
	}

	// Serialize payouts per baker so two concurrent requests can't both pay.
	if err := s.idem.Save(ctx, payoutScope, bakerID, "1"); err != nil {
		if errors.Is(err, pkg.ErrIdempotencyConflict) {
			return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "a payout is already in progress")
		}
		return nil, err
	}
	defer func() { _ = s.idem.Delete(ctx, payoutScope, bakerID) }()

	available, err := s.ledger.BakerAvailableBalance(ctx, bakerID)
	if err != nil {
		return nil, err
	}
	if available <= 0 {
		return nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation, "no funds available for payout")
	}
	phone, err := s.repo.BakerPhone(ctx, bakerID)
	if err != nil {
		return nil, err
	}

	payout, err := s.repo.CreatePayout(ctx, bakerID, available)
	if err != nil {
		return nil, err
	}

	res, err := s.psp.Payout(ctx, pspclient.PayoutRequest{
		BakerID: bakerID, Phone: phone, Amount: available, IdempotencyKey: idemKey,
	})
	if err != nil {
		_, _ = s.repo.UpdatePayoutStatus(ctx, payout.ID, PayoutFailed, "")
		return nil, err
	}
	if err := s.ledger.RecordPayout(ctx, bakerID, available); err != nil {
		_, _ = s.repo.UpdatePayoutStatus(ctx, payout.ID, PayoutFailed, res.PSPRef)
		return nil, err
	}
	paid, err := s.repo.UpdatePayoutStatus(ctx, payout.ID, PayoutPaid, res.PSPRef)
	if err != nil {
		return nil, err
	}

	s.notify.Notify(ctx, actor.UserID, notifications.TypePayoutSent,
		map[string]any{"payout_id": paid.ID, "amount": paid.Amount})
	return paid, nil
}

// HandleWebhook reconciles a PSP settlement callback. It is idempotent: each PSP
// reference is processed at most once (Redis reservation + ledger guards), so
// retried deliveries never double-credit. Returns a short status word.
func (s *Service) HandleWebhook(ctx context.Context, signature string, body []byte) (string, error) {
	event, err := s.psp.VerifyWebhook(ctx, signature, body)
	if err != nil {
		return "", pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeBadRequest, "invalid webhook payload")
	}
	if event.PSPRef == "" {
		return "ignored", nil
	}
	return s.settleRef(ctx, event.PSPRef, event.Status)
}

// settleRef applies a terminal settlement to the payment with the given PSP
// reference. It is the shared core of webhook reconciliation and of synchronous
// (inline) settlement, and is idempotent via a per-reference reservation.
func (s *Service) settleRef(ctx context.Context, pspRef, status string) (string, error) {
	// Reserve the reference; a duplicate delivery short-circuits here.
	if err := s.idem.Save(ctx, webhookScope, pspRef, "1"); err != nil {
		if errors.Is(err, pkg.ErrIdempotencyConflict) {
			return "duplicate", nil
		}
		return "", err
	}
	release := func(e error) (string, error) {
		_ = s.idem.Delete(ctx, webhookScope, pspRef)
		return "", e
	}

	payment, err := s.repo.GetByPSPRef(ctx, pspRef)
	if errors.Is(err, pkg.ErrNotFound) {
		return "ignored", nil // unknown reference; keep it reserved
	}
	if err != nil {
		return release(err)
	}
	if payment.Status == StatusSucceeded {
		return "already_processed", nil
	}
	if status != "succeeded" {
		if err := s.repo.UpdateStatus(ctx, payment.ID, StatusFailed); err != nil {
			return release(err)
		}
		return "failed", nil
	}

	order, err := s.orders.OrderByID(ctx, payment.OrderID)
	if err != nil {
		return release(err)
	}
	switch payment.Kind {
	case KindDeposit:
		if err := s.ledger.RecordDeposit(ctx, order.ID, order.CustomerID, order.BakerID, payment.Amount); err != nil {
			return release(err)
		}
		if err := s.orders.MarkDepositPaid(ctx, order.ID); err != nil {
			return release(err)
		}
		s.notify.Notify(ctx, order.CustomerID, notifications.TypeDepositConfirmed,
			map[string]any{"order_id": order.ID, "amount": payment.Amount})
	case KindBalance:
		if err := s.ledger.RecordBalanceAndRelease(ctx, order.ID, order.CustomerID, order.BakerID,
			payment.Amount, order.TotalAmount, order.CommissionAmount); err != nil {
			return release(err)
		}
		if err := s.orders.MarkCompleted(ctx, order.ID); err != nil {
			return release(err)
		}
		s.notify.Notify(ctx, order.CustomerID, notifications.TypeOrderCompleted, map[string]any{"order_id": order.ID})
		s.notify.Notify(ctx, order.CustomerID, notifications.TypeReviewRequest, map[string]any{"order_id": order.ID})
		if bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID); err == nil {
			s.notify.Notify(ctx, bakerUserID, notifications.TypeOrderCompleted, map[string]any{"order_id": order.ID})
		}
	case KindRefund:
		if err := s.ledger.RecordRefund(ctx, order.ID, order.CustomerID, order.BakerID, payment.Amount); err != nil {
			return release(err)
		}
	}

	if err := s.repo.UpdateStatus(ctx, payment.ID, StatusSucceeded); err != nil {
		return release(err)
	}
	return "processed", nil
}
