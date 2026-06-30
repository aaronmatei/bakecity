package search

import (
	"context"
	"net/http"
	"time"

	"github.com/corebalt/bakecity/pkg"
	"github.com/corebalt/bakecity/pkg/storage"
)

// productImageTTL is how long a presigned product-image URL stays valid.
const productImageTTL = 6 * time.Hour

// Service implements search business logic.
type Service struct {
	repo      *Repository
	presigner storage.Presigner
}

// NewService constructs a Service.
func NewService(repo *Repository, presigner storage.Presigner) *Service {
	return &Service{repo: repo, presigner: presigner}
}

// SearchBakers validates and runs a baker discovery query.
func (s *Service) SearchBakers(ctx context.Context, q BakerSearchQuery) ([]BakerResult, error) {
	if err := validateGeo(q.Lat, q.Lng); err != nil {
		return nil, err
	}
	results, err := s.repo.SearchBakers(ctx, q)
	if err != nil {
		return nil, err
	}
	// Resolve cover image keys to viewable URLs (seeded covers are full URLs).
	for i := range results {
		results[i].CoverImageURL =
			storage.ResolveURL(ctx, s.presigner, results[i].CoverImageURL, productImageTTL)
	}
	return results, nil
}

// SearchProducts validates and runs a product discovery query.
func (s *Service) SearchProducts(ctx context.Context, q ProductSearchQuery) ([]ProductResult, error) {
	if err := validateGeo(q.Lat, q.Lng); err != nil {
		return nil, err
	}
	results, err := s.repo.SearchProducts(ctx, q)
	if err != nil {
		return nil, err
	}
	// Resolve image keys to viewable URLs (seeded images already hold a full
	// URL; uploaded ones are presigned).
	for i := range results {
		for j, key := range results[i].ImageURLs {
			results[i].ImageURLs[j] =
				storage.ResolveURL(ctx, s.presigner, key, productImageTTL)
		}
	}
	return results, nil
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
