package orders

import (
	"context"
	"math"
	"net/http"
	"time"

	"github.com/corebalt/bakecity/internal/ledger"
	"github.com/corebalt/bakecity/internal/notifications"
	"github.com/corebalt/bakecity/pkg"
)

// Actor identifies the authenticated caller for authorization checks.
type Actor struct {
	UserID  string
	IsAdmin bool
}

// Service implements order business logic, including scheduling guards and the
// state-machine transitions.
type Service struct {
	repo   *Repository
	ledger *ledger.Service
	notify *notifications.Service
	now    func() time.Time
}

// NewService constructs a Service.
func NewService(repo *Repository, ledgerSvc *ledger.Service, notifySvc *notifications.Service) *Service {
	return &Service{repo: repo, ledger: ledgerSvc, notify: notifySvc, now: time.Now}
}

// Create validates fulfillment and creates an order in QUOTE_REQUESTED.
func (s *Service) Create(ctx context.Context, customerID string, req CreateOrderRequest) (*Order, error) {
	eventDate, err := time.Parse("2006-01-02", req.EventDate)
	if err != nil {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "invalid event_date (want YYYY-MM-DD)")
	}
	if (req.Lat == nil) != (req.Lng == nil) {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "lat and lng must be provided together")
	}

	sched, err := s.repo.BakerScheduling(ctx, req.BakerID)
	if err != nil {
		return nil, err // ErrNotFound -> 404
	}
	if sched.Status != "approved" {
		return nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation, "baker is not accepting orders")
	}
	if err := s.checkFulfillment(ctx, req.BakerID, *sched, eventDate, ""); err != nil {
		return nil, err
	}

	specs := make([]OrderSpec, 0, len(req.Specs))
	for _, in := range req.Specs {
		specs = append(specs, OrderSpec{Key: in.Key, Value: in.Value})
	}
	o := &Order{
		CustomerID:      customerID,
		BakerID:         req.BakerID,
		ProductID:       req.ProductID,
		DeliveryAddress: req.DeliveryAddress,
		Status:          StatusQuoteRequested,
	}
	return s.repo.Create(ctx, o, eventDate, req.Lat, req.Lng, specs)
}

// Get returns an order (with specs) if the actor participates in it.
func (s *Service) Get(ctx context.Context, actor Actor, id string) (*Order, error) {
	o, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if err := s.authorize(ctx, actor, o); err != nil {
		return nil, err
	}
	specs, err := s.repo.GetSpecs(ctx, id)
	if err != nil {
		return nil, err
	}
	o.Specs = specs
	return o, nil
}

// List returns the actor's orders as customer and/or baker.
func (s *Service) List(ctx context.Context, actor Actor, f ListFilter) ([]Order, error) {
	bakerID, err := s.repo.BakerIDForUser(ctx, actor.UserID)
	if err != nil {
		return nil, err
	}
	return s.repo.List(ctx, actor.UserID, bakerID, f)
}

// Cancellation refund policy defaults (architecture §7). These are platform-wide
// defaults; making them per-baker is a future extension.
const (
	cancelProcessingFeePct = 0.10 // platform fee when a customer cancels after the deposit is paid
	inProductionForfeitPct = 0.50 // deposit share the customer forfeits once production has started
)

// CancelSettlement is how a cancelled order's held deposit is divided.
type CancelSettlement struct {
	ToCustomer  float64 `json:"to_customer"`
	ToBaker     float64 `json:"to_baker"`
	ToPlatform  float64 `json:"to_platform"`
	FinalStatus string  `json:"-"`
}

// cancellationSettlement applies the §7 refund matrix. deposit is the escrow
// held (0 before DEPOSIT_PAID); role is "customer", "baker", or "admin". Legs
// always sum to the held amount.
func cancellationSettlement(status, role string, deposit float64) CancelSettlement {
	var held float64
	switch status {
	case StatusDepositPaid, StatusInProduction, StatusReady, StatusOutForDelivery:
		held = deposit
	}
	if held <= 0 {
		return CancelSettlement{FinalStatus: StatusCancelled}
	}
	// Baker (can't fulfill) or admin cancellation makes the customer whole.
	if role != "customer" {
		return CancelSettlement{ToCustomer: round2(held), FinalStatus: StatusRefunded}
	}
	// Customer cancellation.
	if status == StatusInProduction {
		gross := round2(held * inProductionForfeitPct) // baker keeps this slice
		commission := round2(gross * CommissionRate)
		return CancelSettlement{
			ToCustomer:  round2(held - gross),
			ToBaker:     round2(gross - commission),
			ToPlatform:  commission,
			FinalStatus: StatusRefunded,
		}
	}
	// DEPOSIT_PAID, before production: refund minus a processing fee.
	fee := round2(held * cancelProcessingFeePct)
	return CancelSettlement{
		ToCustomer:  round2(held - fee),
		ToPlatform:  fee,
		FinalStatus: StatusRefunded,
	}
}

// Cancel cancels a pre-DELIVERED order, applying the §7 refund matrix to any
// held deposit. A customer may cancel only through IN_PRODUCTION; once an order
// is READY or later the customer must raise a dispute. A baker (who can't
// fulfill) or an admin may cancel at any pre-DELIVERED stage with a full refund.
func (s *Service) Cancel(ctx context.Context, actor Actor, id string) (*Order, error) {
	o, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	role := s.roleOf(ctx, actor, o)
	if role == "" {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "not a participant in this order")
	}
	if !CanTransition(o.Status, StatusCancelled) {
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "order cannot be cancelled from "+o.Status)
	}
	if role == "customer" && (o.Status == StatusReady || o.Status == StatusOutForDelivery) {
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict,
			"order can no longer be cancelled by the customer; please raise a dispute")
	}

	st := cancellationSettlement(o.Status, role, o.DepositAmount)
	if st.ToCustomer > 0 || st.ToBaker > 0 || st.ToPlatform > 0 {
		if err := s.ledger.SettleCancellation(ctx, o.ID, o.CustomerID, o.BakerID,
			st.ToCustomer, st.ToBaker, st.ToPlatform); err != nil {
			return nil, err
		}
	}
	if err := s.repo.UpdateStatus(ctx, id, st.FinalStatus); err != nil {
		return nil, err
	}
	o.Status = st.FinalStatus

	payload := map[string]any{"order_id": o.ID, "refund": st.ToCustomer, "cancelled_by": role}
	s.notify.Notify(ctx, o.CustomerID, notifications.TypeOrderCancelled, payload)
	if bakerUserID, err := s.BakerUserID(ctx, o.BakerID); err == nil {
		s.notify.Notify(ctx, bakerUserID, notifications.TypeOrderCancelled, payload)
	}
	return o, nil
}

// roleOf classifies the actor's relationship to an order: "admin", "customer",
// "baker", or "" if not a participant.
func (s *Service) roleOf(ctx context.Context, actor Actor, o *Order) string {
	if actor.IsAdmin {
		return "admin"
	}
	if o.CustomerID == actor.UserID {
		return "customer"
	}
	if sched, err := s.repo.BakerScheduling(ctx, o.BakerID); err == nil && sched.UserID == actor.UserID {
		return "baker"
	}
	return ""
}

// checkFulfillment enforces the scheduling guards: lead time, blackout dates,
// and daily capacity. excludeOrderID omits one order from the capacity count
// (used when re-validating an order that already occupies a slot).
func (s *Service) checkFulfillment(ctx context.Context, bakerID string, sched bakerScheduling, eventDate time.Time, excludeOrderID string) error {
	today := s.now().UTC().Truncate(24 * time.Hour)
	earliest := today.AddDate(0, 0, sched.LeadTimeDays)
	if eventDate.Before(earliest) {
		return pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation,
			"event date is sooner than the baker's lead time")
	}
	blackout, err := s.repo.IsBlackout(ctx, bakerID, eventDate)
	if err != nil {
		return err
	}
	if blackout {
		return pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation,
			"baker is unavailable on that date")
	}
	count, err := s.repo.CountOrdersOn(ctx, bakerID, eventDate, excludeOrderID)
	if err != nil {
		return err
	}
	if count >= sched.DailyCapacity {
		return pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation,
			"baker is fully booked on that date")
	}
	return nil
}

// CommissionRate is the platform commission taken on completed orders (5%).
const CommissionRate = 0.05

// OrderByID loads an order without authorization (for use by collaborating
// domains such as quotes, which apply their own checks).
func (s *Service) OrderByID(ctx context.Context, id string) (*Order, error) {
	return s.repo.GetByID(ctx, id)
}

// BakerUserID returns the user id that owns a baker profile.
func (s *Service) BakerUserID(ctx context.Context, bakerID string) (string, error) {
	sched, err := s.repo.BakerScheduling(ctx, bakerID)
	if err != nil {
		return "", err
	}
	return sched.UserID, nil
}

// BakerIDForUser resolves the baker profile id owned by a user, or "" if the
// user has no baker profile.
func (s *Service) BakerIDForUser(ctx context.Context, userID string) (string, error) {
	return s.repo.BakerIDForUser(ctx, userID)
}

// OnQuoteProposed moves an order into QUOTED when a baker proposes (or revises)
// a quote. Valid from QUOTE_REQUESTED, NEGOTIATING, or QUOTED (idempotent).
func (s *Service) OnQuoteProposed(ctx context.Context, orderID string) error {
	o, err := s.repo.GetByID(ctx, orderID)
	if err != nil {
		return err
	}
	switch o.Status {
	case StatusQuoteRequested, StatusNegotiating, StatusQuoted:
		return s.repo.UpdateStatus(ctx, orderID, StatusQuoted)
	default:
		return pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "cannot quote an order in "+o.Status)
	}
}

// OnCustomerOffer moves an order into NEGOTIATING when the customer suggests a
// price (their opening offer or a counter to the baker's quote).
func (s *Service) OnCustomerOffer(ctx context.Context, orderID string) error {
	o, err := s.repo.GetByID(ctx, orderID)
	if err != nil {
		return err
	}
	switch o.Status {
	case StatusQuoteRequested, StatusQuoted:
		return s.repo.UpdateStatus(ctx, orderID, StatusNegotiating)
	case StatusNegotiating:
		return nil // already negotiating; another offer is fine
	default:
		return pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "cannot make an offer on an order in "+o.Status)
	}
}

// OnQuoteAccepted re-validates fulfillment, records the financial breakdown, and
// transitions the order to APPROVED. depositPct is a percentage (0-100).
func (s *Service) OnQuoteAccepted(ctx context.Context, orderID string, total, depositPct float64) (*Order, error) {
	o, err := s.repo.GetByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if o.Status != StatusQuoted {
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "order is not awaiting acceptance")
	}
	sched, err := s.repo.BakerScheduling(ctx, o.BakerID)
	if err != nil {
		return nil, err
	}
	if o.EventDate != nil {
		if err := s.checkFulfillment(ctx, o.BakerID, *sched, *o.EventDate, o.ID); err != nil {
			return nil, err
		}
	}
	deposit := round2(total * depositPct / 100)
	commission := round2(total * CommissionRate)
	balance := round2(total - deposit)
	if err := s.repo.SetAmountsAndStatus(ctx, orderID, total, deposit, balance, commission, StatusApproved); err != nil {
		return nil, err
	}
	o.TotalAmount, o.DepositAmount, o.BalanceAmount, o.CommissionAmount = total, deposit, balance, commission
	o.Status = StatusApproved
	return o, nil
}

// round2 rounds a monetary value to two decimal places.
func round2(v float64) float64 {
	return math.Round(v*100) / 100
}

// MarkDepositPending moves an APPROVED order to DEPOSIT_PENDING when a deposit
// collection is initiated. Idempotent if already pending.
func (s *Service) MarkDepositPending(ctx context.Context, id string) error {
	return s.advance(ctx, id, StatusApproved, StatusDepositPending)
}

// MarkDepositPaid moves a DEPOSIT_PENDING order to DEPOSIT_PAID on confirmed
// deposit settlement. Idempotent if already paid.
func (s *Service) MarkDepositPaid(ctx context.Context, id string) error {
	return s.advance(ctx, id, StatusDepositPending, StatusDepositPaid)
}

// MarkCompleted moves a DELIVERED order to COMPLETED on confirmed balance
// settlement. Idempotent if already completed.
func (s *Service) MarkCompleted(ctx context.Context, id string) error {
	return s.advance(ctx, id, StatusDelivered, StatusCompleted)
}

// StartProduction moves a DEPOSIT_PAID order to IN_PRODUCTION when the baker
// posts the first production update. Idempotent if already in production.
func (s *Service) StartProduction(ctx context.Context, id string) error {
	return s.advance(ctx, id, StatusDepositPaid, StatusInProduction)
}

// MarkReady moves an IN_PRODUCTION order to READY when production completes.
// Idempotent if already ready.
func (s *Service) MarkReady(ctx context.Context, id string) error {
	return s.advance(ctx, id, StatusInProduction, StatusReady)
}

// MarkDispatched moves a READY order to OUT_FOR_DELIVERY when the baker
// dispatches it. Idempotent if already out for delivery.
func (s *Service) MarkDispatched(ctx context.Context, id string) error {
	return s.advance(ctx, id, StatusReady, StatusOutForDelivery)
}

// MarkDelivered moves an OUT_FOR_DELIVERY order to DELIVERED on confirmed
// receipt, which issues the balance invoice. Idempotent if already delivered.
func (s *Service) MarkDelivered(ctx context.Context, id string) error {
	return s.advance(ctx, id, StatusOutForDelivery, StatusDelivered)
}

// MarkRefunded moves a CANCELLED order to REFUNDED once its refund has been
// processed. Idempotent if already refunded.
func (s *Service) MarkRefunded(ctx context.Context, id string) error {
	return s.advance(ctx, id, StatusCancelled, StatusRefunded)
}

// RaiseDispute freezes an order by moving it to DISPUTED from any state where a
// dispute is permitted (funds held). Idempotent if already disputed.
func (s *Service) RaiseDispute(ctx context.Context, id string) (*Order, error) {
	o, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if o.Status == StatusDisputed {
		return o, nil // idempotent
	}
	if !CanTransition(o.Status, StatusDisputed) {
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "order cannot be disputed from "+o.Status)
	}
	if err := s.repo.UpdateStatus(ctx, id, StatusDisputed); err != nil {
		return nil, err
	}
	o.Status = StatusDisputed
	return o, nil
}

// ResolveDispute moves a DISPUTED order to a terminal resolution: COMPLETED
// (released to the baker) or REFUNDED (returned to the customer).
func (s *Service) ResolveDispute(ctx context.Context, id, toStatus string) (*Order, error) {
	if toStatus != StatusCompleted && toStatus != StatusRefunded {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "a dispute resolves to COMPLETED or REFUNDED")
	}
	o, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if o.Status != StatusDisputed {
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "order is not under dispute")
	}
	if err := s.repo.UpdateStatus(ctx, id, toStatus); err != nil {
		return nil, err
	}
	o.Status = toStatus
	return o, nil
}

// advance transitions an order from `from` to `to`; a no-op if already at `to`,
// and a 409 from any other state.
func (s *Service) advance(ctx context.Context, id, from, to string) error {
	o, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return err
	}
	switch o.Status {
	case to:
		return nil // idempotent
	case from:
		return s.repo.UpdateStatus(ctx, id, to)
	default:
		return pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict,
			"order in "+o.Status+" cannot move to "+to)
	}
}

// authorize permits the order's customer, its baker, or an admin.
func (s *Service) authorize(ctx context.Context, actor Actor, o *Order) error {
	if actor.IsAdmin || o.CustomerID == actor.UserID {
		return nil
	}
	sched, err := s.repo.BakerScheduling(ctx, o.BakerID)
	if err == nil && sched.UserID == actor.UserID {
		return nil
	}
	return pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "not a participant in this order")
}
