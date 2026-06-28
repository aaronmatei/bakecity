package production

import (
	"context"
	"net/http"

	"github.com/corebalt/bakecity/internal/notifications"
	"github.com/corebalt/bakecity/internal/orders"
	"github.com/corebalt/bakecity/pkg"
)

// Actor identifies the authenticated caller for authorization checks.
type Actor struct {
	UserID  string
	IsAdmin bool
}

// Service implements production business logic. It collaborates with the orders
// service to authorize callers and to advance the order's state machine as
// production starts and completes.
type Service struct {
	repo   *Repository
	orders *orders.Service
	notify *notifications.Service
}

// NewService constructs a Service.
func NewService(repo *Repository, ordersSvc *orders.Service, notifySvc *notifications.Service) *Service {
	return &Service{repo: repo, orders: ordersSvc, notify: notifySvc}
}

// Add records a production update posted by the order's baker. The first update
// on a DEPOSIT_PAID order starts production (-> IN_PRODUCTION); an update at
// 100% progress marks it ready (-> READY).
func (s *Service) Add(ctx context.Context, actor Actor, orderID string, req CreateUpdateRequest) (*Update, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID)
	if err != nil {
		return nil, err
	}
	if !actor.IsAdmin && actor.UserID != bakerUserID {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "only the order's baker can post production updates")
	}

	switch order.Status {
	case orders.StatusDepositPaid:
		if err := s.orders.StartProduction(ctx, orderID); err != nil {
			return nil, err
		}
	case orders.StatusInProduction:
		// already in production; accept further updates
	default:
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict,
			"order is not in production (status: "+order.Status+")")
	}

	upd, err := s.repo.Insert(ctx, orderID, req.Stage, req.ProgressPct, req.Notes, req.MediaID)
	if err != nil {
		return nil, err
	}

	if req.ProgressPct >= 100 {
		if err := s.orders.MarkReady(ctx, orderID); err != nil {
			return nil, err
		}
	}
	s.notify.Notify(ctx, order.CustomerID, notifications.TypeProductionUpdate,
		map[string]any{"order_id": orderID, "stage": upd.Stage, "progress_pct": upd.ProgressPct})
	return upd, nil
}

// List returns an order's production timeline; participants and admins only.
func (s *Service) List(ctx context.Context, actor Actor, orderID string) ([]Update, error) {
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
