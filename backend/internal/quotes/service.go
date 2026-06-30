package quotes

import (
	"context"
	"net/http"
	"time"

	"github.com/corebalt/bakecity/internal/notifications"
	"github.com/corebalt/bakecity/internal/orders"
	"github.com/corebalt/bakecity/pkg"
)

// Actor identifies the authenticated caller for authorization checks.
type Actor struct {
	UserID  string
	IsAdmin bool
}

// Service implements quote business logic. It collaborates with the orders
// service to validate and advance the order's state machine.
type Service struct {
	repo   *Repository
	orders *orders.Service
	notify *notifications.Service
}

// NewService constructs a Service.
func NewService(repo *Repository, ordersSvc *orders.Service, notifySvc *notifications.Service) *Service {
	return &Service{repo: repo, orders: ordersSvc, notify: notifySvc}
}

// Propose lets the order's baker offer (or revise) a quote, moving the order to
// QUOTED.
func (s *Service) Propose(ctx context.Context, actor Actor, orderID string, req CreateQuoteRequest) (*Quote, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID)
	if err != nil {
		return nil, err
	}
	if !actor.IsAdmin && actor.UserID != bakerUserID {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "only the order's baker can quote")
	}

	var validUntil *time.Time
	if req.ValidUntil != "" {
		t, perr := time.Parse(time.RFC3339, req.ValidUntil)
		if perr != nil {
			return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "invalid valid_until (want RFC3339)")
		}
		validUntil = &t
	}

	// Advance the order's state first so an invalid state fails before insert.
	if err := s.orders.OnQuoteProposed(ctx, orderID); err != nil {
		return nil, err
	}
	q, err := s.repo.Create(ctx, orderID, req.Amount, req.DepositPct, req.DeliveryFee, validUntil, ProposedByBaker, req.IsFinal)
	if err != nil {
		return nil, err
	}
	s.notify.Notify(ctx, order.CustomerID, notifications.TypeQuoteProposed,
		map[string]any{"order_id": orderID, "quote_id": q.ID, "amount": q.Amount})
	return q, nil
}

// SuggestOffer lets the order's customer propose a price during negotiation,
// moving the order to NEGOTIATING. It's a non-binding suggestion — the baker
// responds with a quote the customer can then accept.
func (s *Service) SuggestOffer(ctx context.Context, actor Actor, orderID string, req SuggestOfferRequest) (*Quote, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if !actor.IsAdmin && actor.UserID != order.CustomerID {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "only the customer can suggest an offer")
	}
	if err := s.orders.OnCustomerOffer(ctx, orderID); err != nil {
		return nil, err
	}
	// A suggestion carries no deposit terms and never expires; the baker sets
	// those when they respond with a quote.
	q, err := s.repo.Create(ctx, orderID, req.Amount, 0, 0, nil, ProposedByCustomer, false)
	if err != nil {
		return nil, err
	}
	if bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID); err == nil {
		s.notify.Notify(ctx, bakerUserID, notifications.TypeOfferSuggested,
			map[string]any{"order_id": orderID, "quote_id": q.ID, "amount": q.Amount})
	}
	return q, nil
}

// Accept lets the order's customer accept a pending quote, re-validating
// fulfillment and moving the order to APPROVED with computed amounts.
func (s *Service) Accept(ctx context.Context, actor Actor, orderID, quoteID string) (*orders.Order, *Quote, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, nil, err
	}
	if !actor.IsAdmin && actor.UserID != order.CustomerID {
		return nil, nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "only the customer can accept a quote")
	}

	q, err := s.repo.GetByID(ctx, quoteID)
	if err != nil {
		return nil, nil, err
	}
	if q.OrderID != orderID {
		return nil, nil, pkg.ErrNotFound
	}
	if q.ProposedBy != ProposedByBaker {
		return nil, nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation, "only the baker's quote can be accepted; this is a customer offer")
	}
	if q.Status != StatusPending {
		return nil, nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "quote is not pending (status: "+q.Status+")")
	}
	if q.ValidUntil != nil && q.ValidUntil.Before(time.Now()) {
		_ = s.repo.SetStatus(ctx, q.ID, StatusExpired)
		return nil, nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation, "quote has expired")
	}

	updated, err := s.orders.OnQuoteAccepted(ctx, orderID, q.Amount, q.DeliveryFee, q.DepositPct)
	if err != nil {
		return nil, nil, err
	}
	if err := s.repo.SetStatus(ctx, q.ID, StatusAccepted); err != nil {
		return nil, nil, err
	}
	q.Status = StatusAccepted
	if bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID); err == nil {
		s.notify.Notify(ctx, bakerUserID, notifications.TypeQuoteAccepted,
			map[string]any{"order_id": orderID, "amount": q.Amount})
	}
	return updated, q, nil
}

// List returns an order's quote versions; participants and admins only.
func (s *Service) List(ctx context.Context, actor Actor, orderID string) ([]Quote, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if err := s.authorizeParticipant(ctx, actor, order); err != nil {
		return nil, err
	}
	return s.repo.ListByOrder(ctx, orderID)
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
