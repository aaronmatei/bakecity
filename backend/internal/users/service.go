package users

import (
	"context"
	"net/http"
	"strings"

	"github.com/corebalt/bakecity/pkg"
)

// Service implements users business logic.
type Service struct {
	repo *Repository
}

// NewService constructs a Service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// GetMe returns the authenticated user's profile.
func (s *Service) GetMe(ctx context.Context, userID string) (*User, error) {
	return s.repo.GetByID(ctx, userID)
}

// UpdateMe applies a partial update to the authenticated user's profile.
func (s *Service) UpdateMe(ctx context.Context, userID string, req UpdateMeRequest) (*User, error) {
	email := strings.TrimSpace(req.Email)
	phone := strings.TrimSpace(req.Phone)
	if email == "" && phone == "" {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "nothing to update")
	}
	if email != "" && !pkg.IsValidEmail(email) {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "invalid email")
	}
	if phone != "" && !pkg.IsValidPhone(phone) {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "invalid phone")
	}
	return s.repo.UpdateProfile(ctx, userID, email, phone)
}
