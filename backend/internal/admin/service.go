package admin

import "context"

// Service implements admin business logic (moderation, dispute resolution,
// refunds). It coordinates across other domains' services in a full build.
type Service struct {
	repo *Repository
}

// NewService constructs a Service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// PendingBakers returns the baker approval queue.
func (s *Service) PendingBakers(ctx context.Context) ([]BakerSummary, error) {
	return s.repo.ListPendingBakers(ctx)
}

// ApproveBaker approves a pending baker profile.
func (s *Service) ApproveBaker(ctx context.Context, id string) (*BakerSummary, error) {
	return s.repo.ApproveBaker(ctx, id)
}
