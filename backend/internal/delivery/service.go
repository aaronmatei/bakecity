package delivery

import (
	"context"
	"log"
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

// Service implements delivery business logic. It collaborates with the orders
// service to authorize callers and to advance the order's state machine through
// dispatch and proof-of-delivery confirmation.
type Service struct {
	repo   *Repository
	orders *orders.Service
	notify *notifications.Service
}

// NewService constructs a Service.
func NewService(repo *Repository, ordersSvc *orders.Service, notifySvc *notifications.Service) *Service {
	return &Service{repo: repo, orders: ordersSvc, notify: notifySvc}
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
	d, err := s.repo.Dispatch(ctx, orderID, req.Method, req.CourierRef)
	if err != nil {
		return nil, err
	}
	s.notify.Notify(ctx, order.CustomerID, notifications.TypeOutForDelivery,
		map[string]any{"order_id": orderID, "method": req.Method})
	return d, nil
}

// SubmitProof records the baker's proof-of-delivery on an OUT_FOR_DELIVERY order
// and nudges the customer to confirm receipt. It does NOT mark the order
// delivered — only the customer's confirmation (or the timed sweep) does that.
// Baker (or admin) only; a proof photo is required.
func (s *Service) SubmitProof(ctx context.Context, actor Actor, orderID string, req ConfirmRequest) (*Delivery, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID)
	if err != nil {
		return nil, err
	}
	if !actor.IsAdmin && actor.UserID != bakerUserID {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "only the order's baker can submit proof-of-delivery")
	}
	if req.ProofMediaID == "" {
		return nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation, "a proof-of-delivery photo is required")
	}
	if order.Status != orders.StatusOutForDelivery {
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict,
			"order is not out for delivery (status: "+order.Status+")")
	}
	d, err := s.repo.SubmitProof(ctx, orderID, req.ProofMediaID)
	if err != nil {
		return nil, err
	}
	s.notify.Notify(ctx, order.CustomerID, notifications.TypeDeliveryProof, map[string]any{"order_id": orderID})
	return d, nil
}

// Confirm finalizes receipt for an OUT_FOR_DELIVERY order, moving it to
// DELIVERED (which issues the balance invoice). Only the customer or an admin
// may confirm — the baker uses SubmitProof and the timed sweep is the fallback.
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
	if role == "baker" {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden,
			"only the customer confirms receipt; submit proof-of-delivery instead")
	}
	return s.markDelivered(ctx, order, req.ProofMediaID)
}

// markDelivered moves an out-for-delivery order to DELIVERED and notifies both
// parties. Shared by customer confirmation and the auto-confirm sweep.
func (s *Service) markDelivered(ctx context.Context, order *orders.Order, proofMediaID string) (*Delivery, error) {
	switch order.Status {
	case orders.StatusOutForDelivery:
		if err := s.orders.MarkDelivered(ctx, order.ID); err != nil {
			return nil, err
		}
	case orders.StatusDelivered:
		// already delivered; idempotent
	default:
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict,
			"order is not out for delivery (status: "+order.Status+")")
	}
	d, err := s.repo.Confirm(ctx, order.ID, proofMediaID)
	if err != nil {
		return nil, err
	}
	s.notify.Notify(ctx, order.CustomerID, notifications.TypeDelivered, map[string]any{"order_id": order.ID})
	if bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID); err == nil {
		s.notify.Notify(ctx, bakerUserID, notifications.TypeDelivered, map[string]any{"order_id": order.ID})
	}
	// Fully-prepaid (buy-now) orders owe no balance, so delivery completes them
	// and releases the escrow to the baker. No-op when a balance is still due.
	if err := s.orders.FinalizeZeroBalance(ctx, order.ID); err != nil {
		return nil, err
	}
	return d, nil
}

// AutoConfirmStale releases to DELIVERED any orders whose baker submitted proof
// more than `window` ago without the customer confirming. Returns how many.
func (s *Service) AutoConfirmStale(ctx context.Context, window time.Duration) (int, error) {
	ids, err := s.repo.ListStaleAwaitingConfirmation(ctx, time.Now().Add(-window))
	if err != nil {
		return 0, err
	}
	n := 0
	for _, id := range ids {
		order, err := s.orders.OrderByID(ctx, id)
		if err != nil {
			continue
		}
		if _, err := s.markDelivered(ctx, order, ""); err != nil {
			log.Printf("auto-confirm: order %s failed: %v", id, err)
			continue
		}
		n++
	}
	return n, nil
}

// RunAutoConfirmLoop periodically auto-confirms stale deliveries until ctx is
// cancelled. Intended to run as a background goroutine.
func (s *Service) RunAutoConfirmLoop(ctx context.Context, interval, window time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()
	log.Printf("delivery auto-confirm sweep every %s, window %s", interval, window)
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if n, err := s.AutoConfirmStale(ctx, window); err != nil {
				log.Printf("delivery auto-confirm sweep failed: %v", err)
			} else if n > 0 {
				log.Printf("delivery auto-confirm: released %d order(s) to delivered", n)
			}
		}
	}
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
