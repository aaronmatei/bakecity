package disputes

import (
	"context"
	"math"
	"net/http"
	"time"

	"github.com/corebalt/bakecity/internal/ledger"
	"github.com/corebalt/bakecity/internal/notifications"
	"github.com/corebalt/bakecity/internal/orders"
	"github.com/corebalt/bakecity/pkg"
)

// Actor identifies the authenticated caller for authorization checks.
type Actor struct {
	UserID  string
	IsAdmin bool
}

// Service implements dispute business logic. Raising a dispute freezes the
// order (-> DISPUTED); an admin ruling settles the held escrow via the ledger
// and resolves the order to COMPLETED or REFUNDED.
type Service struct {
	repo   *Repository
	orders *orders.Service
	ledger *ledger.Service
	notify *notifications.Service
	now    func() time.Time
}

// NewService constructs a Service.
func NewService(repo *Repository, ordersSvc *orders.Service, ledgerSvc *ledger.Service, notifySvc *notifications.Service) *Service {
	return &Service{repo: repo, orders: ordersSvc, ledger: ledgerSvc, notify: notifySvc, now: time.Now}
}

// notifyParticipants sends a notification to both the order's customer and baker.
func (s *Service) notifyParticipants(ctx context.Context, order *orders.Order, notifType string, payload map[string]any) {
	s.notify.Notify(ctx, order.CustomerID, notifType, payload)
	if bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID); err == nil {
		s.notify.Notify(ctx, bakerUserID, notifType, payload)
	}
}

// Raise lets a participant open a dispute on an order, freezing it (-> DISPUTED).
func (s *Service) Raise(ctx context.Context, actor Actor, orderID string, req CreateDisputeRequest) (*Dispute, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if err := s.authorizeParticipant(ctx, actor, order); err != nil {
		return nil, err
	}
	if _, err := s.orders.RaiseDispute(ctx, orderID); err != nil {
		return nil, err
	}
	d, err := s.repo.Create(ctx, orderID, actor.UserID, req.Reason)
	if err != nil {
		return nil, err
	}
	s.notifyParticipants(ctx, order, notifications.TypeDisputeRaised, map[string]any{"order_id": orderID, "dispute_id": d.ID})
	return d, nil
}

// ListForOrder returns an order's disputes; participants and admins only.
func (s *Service) ListForOrder(ctx context.Context, actor Actor, orderID string) ([]Dispute, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if err := s.authorizeParticipant(ctx, actor, order); err != nil {
		return nil, err
	}
	return s.repo.ListByOrder(ctx, orderID)
}

// ListByStatus returns disputes in a given status (defaulting to open) for the
// admin queue. Caller must already be admin-gated.
func (s *Service) ListByStatus(ctx context.Context, status string, limit, offset int) ([]Dispute, error) {
	if status == "" {
		status = StatusOpen
	}
	return s.repo.ListByStatus(ctx, status, limit, offset)
}

// Resolve applies an admin ruling to an open dispute: it refunds refundAmount
// (clamped to the held deposit) to the customer, releases the remainder to the
// baker net of commission, and resolves the order. A full refund settles the
// order as REFUNDED; otherwise it completes.
func (s *Service) Resolve(ctx context.Context, adminUserID, disputeID, resolution string, refundAmount float64) (*Dispute, error) {
	d, err := s.repo.GetByID(ctx, disputeID)
	if err != nil {
		return nil, err
	}
	if d.Status != StatusOpen {
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "dispute is already resolved")
	}
	order, err := s.orders.OrderByID(ctx, d.OrderID)
	if err != nil {
		return nil, err
	}

	// escrow held at dispute time is the deposit
	refund, bakerPortion, commission, toStatus := settlement(order.DepositAmount, refundAmount)

	if err := s.ledger.SettleDispute(ctx, order.ID, order.CustomerID, order.BakerID, refund, bakerPortion, commission); err != nil {
		return nil, err
	}
	if _, err := s.orders.ResolveDispute(ctx, order.ID, toStatus); err != nil {
		return nil, err
	}

	resolved, err := s.repo.Resolve(ctx, disputeID, StatusResolved, resolution, refund, adminUserID, s.now().UTC())
	if err != nil {
		return nil, err
	}
	s.notifyParticipants(ctx, order, notifications.TypeDisputeResolved,
		map[string]any{"order_id": order.ID, "dispute_id": resolved.ID, "refund_amount": refund, "outcome": toStatus})
	return resolved, nil
}

// authorizeParticipant permits the order's customer, its baker, or an admin.
func (s *Service) authorizeParticipant(ctx context.Context, actor Actor, order *orders.Order) error {
	if actor.IsAdmin || order.CustomerID == actor.UserID {
		return nil
	}
	bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID)
	if err == nil && bakerUserID == actor.UserID {
		return nil
	}
	return pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "not a participant in this order")
}

// settlement computes how a disputed order's held escrow is divided given the
// admin's requested refund: the (clamped) refund to the customer, the baker's
// released portion, the platform commission on it, and the resulting order
// status. A full refund settles as REFUNDED; anything the baker keeps COMPLETES.
func settlement(held, refundReq float64) (refund, bakerPortion, commission float64, toStatus string) {
	refund = refundReq
	if refund < 0 {
		refund = 0
	}
	if refund > held {
		refund = held
	}
	bakerPortion = round2(held - refund)
	commission = round2(bakerPortion * orders.CommissionRate)
	toStatus = orders.StatusCompleted
	if refund > 0 && bakerPortion == 0 {
		toStatus = orders.StatusRefunded
	}
	return refund, bakerPortion, commission, toStatus
}

// round2 rounds a monetary value to two decimal places.
func round2(v float64) float64 {
	return math.Round(v*100) / 100
}
