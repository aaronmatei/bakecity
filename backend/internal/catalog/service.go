package catalog

import (
	"context"
	"errors"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/corebalt/bakecity/pkg"
	"github.com/corebalt/bakecity/pkg/storage"
)

var nonSlugChars = regexp.MustCompile(`[^a-z0-9]+`)

// productImageTTL is how long a presigned product-image URL stays valid.
const productImageTTL = 6 * time.Hour

// Actor identifies the authenticated caller for authorization checks.
type Actor struct {
	UserID  string
	IsAdmin bool
}

// Service implements catalog business logic.
type Service struct {
	repo      *Repository
	presigner storage.Presigner
}

// NewService constructs a Service.
func NewService(repo *Repository, presigner storage.Presigner) *Service {
	return &Service{repo: repo, presigner: presigner}
}

// resolveImages turns each product's stored image keys into viewable URLs
// (seeded images already hold a full URL; uploaded ones are presigned).
func (s *Service) resolveImages(ctx context.Context, products ...*Product) {
	for _, p := range products {
		if p == nil {
			continue
		}
		for i, key := range p.ImageURLs {
			p.ImageURLs[i] = storage.ResolveURL(ctx, s.presigner, key, productImageTTL)
		}
	}
}

// ---- Categories ----

// ListCategories returns all product categories.
func (s *Service) ListCategories(ctx context.Context) ([]Category, error) {
	return s.repo.ListCategories(ctx)
}

// CreateCategory creates a category; admins only. The slug is derived from the
// name when not supplied.
func (s *Service) CreateCategory(ctx context.Context, actor Actor, req CreateCategoryRequest) (*Category, error) {
	if !actor.IsAdmin {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "admin role required")
	}
	slug := slugify(req.Slug)
	if slug == "" {
		slug = slugify(req.Name)
	}
	if slug == "" {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "could not derive a slug")
	}
	return s.repo.CreateCategory(ctx, strings.TrimSpace(req.Name), slug)
}

// ---- Products ----

// ListProducts returns products matching the filter.
func (s *Service) ListProducts(ctx context.Context, f ProductFilter) ([]Product, error) {
	products, err := s.repo.ListProducts(ctx, f)
	if err != nil {
		return nil, err
	}
	for i := range products {
		s.resolveImages(ctx, &products[i])
	}
	return products, nil
}

// GetProduct returns a single product.
func (s *Service) GetProduct(ctx context.Context, id string) (*Product, error) {
	p, err := s.repo.GetProduct(ctx, id)
	if err != nil {
		return nil, err
	}
	s.resolveImages(ctx, p)
	return p, nil
}

// CreateProduct creates a product for the authenticated user's baker profile.
func (s *Service) CreateProduct(ctx context.Context, userID string, req CreateProductRequest) (*Product, error) {
	bakerID, err := s.repo.BakerIDForUser(ctx, userID)
	if errors.Is(err, pkg.ErrNotFound) {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "you must create a baker profile first")
	}
	if err != nil {
		return nil, err
	}
	return s.repo.CreateProduct(ctx, bakerID, req)
}

// UpdateProduct modifies a product; only its owning baker or an admin may do so.
func (s *Service) UpdateProduct(ctx context.Context, actor Actor, id string, req UpdateProductRequest) (*Product, error) {
	_, ownerUserID, err := s.repo.ProductOwner(ctx, id)
	if err != nil {
		return nil, err
	}
	if !actor.IsAdmin && ownerUserID != actor.UserID {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "not the owner of this product")
	}
	return s.repo.UpdateProduct(ctx, id, req)
}

// slugify lowercases s and replaces runs of non-alphanumerics with single
// hyphens, trimming leading/trailing hyphens.
func slugify(s string) string {
	s = strings.ToLower(strings.TrimSpace(s))
	s = nonSlugChars.ReplaceAllString(s, "-")
	return strings.Trim(s, "-")
}
