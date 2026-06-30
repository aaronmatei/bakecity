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

// ListBakers returns a user's favorited baker ids.
func (s *Service) ListBakers(ctx context.Context, userID string) ([]string, error) {
	return s.repo.ListBakerIDs(ctx, userID)
}

// AddBaker favorites a bakery for a user.
func (s *Service) AddBaker(ctx context.Context, userID, bakerID string) error {
	return s.repo.AddBaker(ctx, userID, bakerID)
}

// RemoveBaker un-favorites a bakery for a user.
func (s *Service) RemoveBaker(ctx context.Context, userID, bakerID string) error {
	return s.repo.RemoveBaker(ctx, userID, bakerID)
}
