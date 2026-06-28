package analytics

import "context"

// Service implements analytics business logic.
type Service struct {
	repo *Repository
}

// NewService constructs a Service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// Overview returns the platform analytics snapshot.
func (s *Service) Overview(ctx context.Context) (*PlatformStats, error) {
	return s.repo.Overview(ctx)
}
