package reviews

import (
	"context"
	"errors"
	"net/http"

	"github.com/corebalt/bakecity/internal/orders"
	"github.com/corebalt/bakecity/pkg"
)

// Actor identifies the authenticated caller for authorization checks.
type Actor struct {
	UserID  string
	IsAdmin bool
}

// Service implements reviews business logic. It uses the orders service to
// verify a reviewer owns a completed order.
type Service struct {
	repo   *Repository
	orders *orders.Service
}

// NewService constructs a Service.
func NewService(repo *Repository, ordersSvc *orders.Service) *Service {
	return &Service{repo: repo, orders: ordersSvc}
}

// Create lets the order's customer review a COMPLETED order exactly once.
func (s *Service) Create(ctx context.Context, actor Actor, req CreateReviewRequest) (*Review, error) {
	order, err := s.orders.OrderByID(ctx, req.OrderID)
	if err != nil {
		return nil, err
	}
	if order.CustomerID != actor.UserID {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "only the order's customer can review it")
	}
	if order.Status != orders.StatusCompleted {
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "only completed orders can be reviewed")
	}
	rev, err := s.repo.Create(ctx, order.ID, actor.UserID, order.BakerID, req.Rating, req.Body)
	if errors.Is(err, pkg.ErrConflict) {
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "this order has already been reviewed")
	}
	return rev, err
}

// GetForOrder returns an order's review; participants and admins only.
func (s *Service) GetForOrder(ctx context.Context, actor Actor, orderID string) (*Review, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if actor.IsAdmin || order.CustomerID == actor.UserID {
		return s.repo.GetByOrder(ctx, orderID)
	}
	bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID)
	if err == nil && bakerUserID == actor.UserID {
		return s.repo.GetByOrder(ctx, orderID)
	}
	return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "not a participant in this order")
}

// ListForBaker returns a baker's reviews and aggregate rating.
func (s *Service) ListForBaker(ctx context.Context, bakerID string, limit, offset int) (*BakerReviews, error) {
	return s.repo.ListByBaker(ctx, bakerID, limit, offset)
}
