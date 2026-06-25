package search

import (
	"context"
	"net/http"

	"github.com/corebalt/bakecity/pkg"
)

// Service implements search business logic.
type Service struct {
	repo *Repository
}

// NewService constructs a Service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// SearchBakers validates and runs a baker discovery query.
func (s *Service) SearchBakers(ctx context.Context, q BakerSearchQuery) ([]BakerResult, error) {
	if err := validateGeo(q.Lat, q.Lng); err != nil {
		return nil, err
	}
	return s.repo.SearchBakers(ctx, q)
}

// SearchProducts validates and runs a product discovery query.
func (s *Service) SearchProducts(ctx context.Context, q ProductSearchQuery) ([]ProductResult, error) {
	if err := validateGeo(q.Lat, q.Lng); err != nil {
		return nil, err
	}
	return s.repo.SearchProducts(ctx, q)
}

// validateGeo ensures lat/lng are supplied together and within valid ranges.
func validateGeo(lat, lng *float64) error {
	if (lat == nil) != (lng == nil) {
		return pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "lat and lng must be provided together")
	}
	if lat != nil {
		if *lat < -90 || *lat > 90 || *lng < -180 || *lng > 180 {
			return pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "lat/lng out of range")
		}
	}
	return nil
}
