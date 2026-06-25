package ledger

import (
	"context"

	"github.com/corebalt/bakecity/pkg"
)

// Service implements ledger business logic. It is an internal accounting module
// used by payments/disputes/admin rather than a public HTTP surface.
type Service struct {
	repo *Repository
}

// NewService constructs a Service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// RecordEscrowDeposit moves a customer deposit into the baker_pending account.
func (s *Service) RecordEscrowDeposit(ctx context.Context, orderID string, amount float64) error {
	_ = ctx
	_ = orderID
	_ = amount
	return pkg.ErrNotImplemented
}

// ReleaseToBaker moves pending funds to baker_available and books commission.
func (s *Service) ReleaseToBaker(ctx context.Context, orderID string, bakerNet, commission float64) error {
	_ = ctx
	_ = orderID
	_ = bakerNet
	_ = commission
	return pkg.ErrNotImplemented
}
