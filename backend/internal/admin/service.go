package admin

import (
	"context"
	"net/http"

	"github.com/corebalt/bakecity/internal/disputes"
	"github.com/corebalt/bakecity/internal/ledger"
	"github.com/corebalt/bakecity/internal/orders"
	"github.com/corebalt/bakecity/pkg"
)

// Service implements admin business logic (moderation, dispute resolution,
// refunds). It coordinates across other domains' services.
type Service struct {
	repo     *Repository
	orders   *orders.Service
	ledger   *ledger.Service
	disputes *disputes.Service
}

// NewService constructs a Service.
func NewService(repo *Repository, ordersSvc *orders.Service, ledgerSvc *ledger.Service, disputesSvc *disputes.Service) *Service {
	return &Service{repo: repo, orders: ordersSvc, ledger: ledgerSvc, disputes: disputesSvc}
}

// PendingBakers returns the baker approval queue.
func (s *Service) PendingBakers(ctx context.Context) ([]BakerSummary, error) {
	return s.repo.ListPendingBakers(ctx)
}

// ApproveBaker approves a pending baker profile.
func (s *Service) ApproveBaker(ctx context.Context, id string) (*BakerSummary, error) {
	return s.repo.ApproveBaker(ctx, id)
}

// ListDisputes returns the dispute queue (defaulting to open) for ops review.
func (s *Service) ListDisputes(ctx context.Context, status string, limit, offset int) ([]disputes.Dispute, error) {
	return s.disputes.ListByStatus(ctx, status, limit, offset)
}

// ResolveDispute applies an admin ruling to an open dispute.
func (s *Service) ResolveDispute(ctx context.Context, adminUserID, disputeID string, req ResolveDisputeRequest) (*disputes.Dispute, error) {
	return s.disputes.Resolve(ctx, adminUserID, disputeID, req.Resolution, req.RefundAmount)
}

// RefundOrder issues an admin refund on a CANCELLED order: it returns the held
// deposit (or the requested amount, clamped) to the customer and resolves the
// order to REFUNDED. Disputed orders are settled via ResolveDispute instead.
func (s *Service) RefundOrder(ctx context.Context, orderID string, req RefundRequest) (*orders.Order, float64, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, 0, err
	}
	if order.Status != orders.StatusCancelled {
		return nil, 0, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict,
			"only a cancelled order can be refunded here (use dispute resolution otherwise)")
	}
	amount := req.Amount
	if amount < 0 {
		amount = 0
	}
	if amount > order.DepositAmount {
		amount = order.DepositAmount
	}
	if amount > 0 {
		if err := s.ledger.RecordRefund(ctx, order.ID, order.CustomerID, order.BakerID, amount); err != nil {
			return nil, 0, err
		}
	}
	if err := s.orders.MarkRefunded(ctx, order.ID); err != nil {
		return nil, 0, err
	}
	order.Status = orders.StatusRefunded
	return order, amount, nil
}
