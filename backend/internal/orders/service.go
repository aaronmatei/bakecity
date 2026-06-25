package orders

import (
	"context"
	"net/http"

	"github.com/corebalt/bakecity/pkg"
)

// Service implements order business logic, including state-machine guards.
type Service struct {
	repo *Repository
}

// NewService constructs a Service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// Get returns an order by id.
func (s *Service) Get(ctx context.Context, id string) (*Order, error) {
	return s.repo.GetByID(ctx, id)
}

// Create creates a new order owned by customerID.
func (s *Service) Create(ctx context.Context, customerID string, req CreateOrderRequest) (string, error) {
	o := &Order{
		CustomerID:      customerID,
		BakerID:         req.BakerID,
		ProductID:       req.ProductID,
		DeliveryAddress: req.DeliveryAddress,
		Status:          StatusDraft,
	}
	return s.repo.Create(ctx, o)
}

// Transition validates and applies an order status change.
func (s *Service) Transition(ctx context.Context, id, to string) error {
	o, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return err
	}
	if !CanTransition(o.Status, to) {
		return pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "invalid status transition")
	}
	return s.repo.UpdateStatus(ctx, id, to)
}
