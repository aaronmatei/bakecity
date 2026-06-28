package delivery

import (
	"context"
	"net/http"

	"github.com/corebalt/bakecity/internal/orders"
	"github.com/corebalt/bakecity/pkg"
)

// Actor identifies the authenticated caller for authorization checks.
type Actor struct {
	UserID  string
	IsAdmin bool
}

// Service implements delivery business logic. It collaborates with the orders
// service to authorize callers and to advance the order's state machine through
// dispatch and proof-of-delivery confirmation.
type Service struct {
	repo   *Repository
	orders *orders.Service
}

// NewService constructs a Service.
func NewService(repo *Repository, ordersSvc *orders.Service) *Service {
	return &Service{repo: repo, orders: ordersSvc}
}

// Dispatch records a dispatch for a READY order; baker (or admin) only. Moves
// the order to OUT_FOR_DELIVERY.
func (s *Service) Dispatch(ctx context.Context, actor Actor, orderID string, req DispatchRequest) (*Delivery, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID)
	if err != nil {
		return nil, err
	}
	if !actor.IsAdmin && actor.UserID != bakerUserID {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "only the order's baker can dispatch")
	}
	if !IsValidMethod(req.Method) {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "unknown delivery method")
	}

	switch order.Status {
	case orders.StatusReady:
		if err := s.orders.MarkDispatched(ctx, orderID); err != nil {
			return nil, err
		}
	case orders.StatusOutForDelivery:
		// already dispatched; allow re-dispatch (e.g. courier change)
	default:
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict,
			"order is not ready for dispatch (status: "+order.Status+")")
	}
	return s.repo.Dispatch(ctx, orderID, req.Method, req.CourierRef)
}

// Confirm records proof-of-delivery and moves an OUT_FOR_DELIVERY order to
// DELIVERED, which issues the balance invoice. The customer or an admin may
// confirm receipt; the baker may confirm only by attaching proof-of-delivery
// (a courier drop-off photo), never on their own say-so.
func (s *Service) Confirm(ctx context.Context, actor Actor, orderID string, req ConfirmRequest) (*Delivery, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	role, err := s.participantRole(ctx, actor, order)
	if err != nil {
		return nil, err
	}
	if role == "" {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "not a participant in this order")
	}
	if role == "baker" && req.ProofMediaID == "" {
		return nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation,
			"a baker must attach proof-of-delivery to confirm receipt")
	}

	switch order.Status {
	case orders.StatusOutForDelivery:
		if err := s.orders.MarkDelivered(ctx, orderID); err != nil {
			return nil, err
		}
	case orders.StatusDelivered:
		// already delivered; allow re-confirm to attach/refresh proof
	default:
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict,
			"order is not out for delivery (status: "+order.Status+")")
	}
	return s.repo.Confirm(ctx, orderID, req.ProofMediaID)
}

// Get returns an order's delivery; participants and admins only.
func (s *Service) Get(ctx context.Context, actor Actor, orderID string) (*Delivery, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	role, err := s.participantRole(ctx, actor, order)
	if err != nil {
		return nil, err
	}
	if role == "" {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "not a participant in this order")
	}
	return s.repo.GetByOrder(ctx, orderID)
}

// participantRole returns "admin", "customer", or "baker" for a participant, or
// "" if the actor is not party to the order.
func (s *Service) participantRole(ctx context.Context, actor Actor, order *orders.Order) (string, error) {
	if actor.IsAdmin {
		return "admin", nil
	}
	if order.CustomerID == actor.UserID {
		return "customer", nil
	}
	bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID)
	if err != nil {
		return "", err
	}
	if bakerUserID == actor.UserID {
		return "baker", nil
	}
	return "", nil
}
