package favorites

import "context"

// Service implements wishlist business logic.
type Service struct {
	repo *Repository
}

// NewService constructs a Service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// List returns a user's favorited product ids.
func (s *Service) List(ctx context.Context, userID string) ([]string, error) {
	return s.repo.ListProductIDs(ctx, userID)
}

// Add favorites a product for a user.
func (s *Service) Add(ctx context.Context, userID, productID string) error {
	return s.repo.Add(ctx, userID, productID)
}

// Remove un-favorites a product for a user.
func (s *Service) Remove(ctx context.Context, userID, productID string) error {
	return s.repo.Remove(ctx, userID, productID)
}
