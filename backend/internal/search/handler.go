package search

import (
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

const (
	defaultPageSize = 20
	maxPageSize     = 100
)

// Handler exposes search HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the search routes (public).
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/search/bakers", h.Bakers)
	rg.GET("/search/products", h.Products)
}

// Bakers handles GET /search/bakers.
func (h *Handler) Bakers(c *gin.Context) {
	limit, offset := paging(c)
	q := BakerSearchQuery{
		Lat:          floatParam(c, "lat"),
		Lng:          floatParam(c, "lng"),
		RadiusKM:     floatParam(c, "radius_km"),
		CategorySlug: c.Query("category"),
		MinPrice:     floatParam(c, "min_price"),
		MaxPrice:     floatParam(c, "max_price"),
		MinRating:    floatParam(c, "min_rating"),
		Q:            c.Query("q"),
		Limit:        limit,
		Offset:       offset,
	}
	results, err := h.svc.SearchBakers(c.Request.Context(), q)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"bakers": results, "limit": limit, "offset": offset})
}

// Products handles GET /search/products.
func (h *Handler) Products(c *gin.Context) {
	limit, offset := paging(c)
	q := ProductSearchQuery{
		Q:            c.Query("q"),
		CategorySlug: c.Query("category"),
		BakerID:      c.Query("baker_id"),
		Occasion:     c.Query("occasion"),
		Flavor:       c.Query("flavor"),
		Format:       c.Query("format"),
		Dietary:      csvParam(c, "dietary"),
		MinPrice:     floatParam(c, "min_price"),
		MaxPrice:     floatParam(c, "max_price"),
		MinRating:    floatParam(c, "min_rating"),
		OnOffer:      boolParam(c, "on_offer"),
		Lat:          floatParam(c, "lat"),
		Lng:          floatParam(c, "lng"),
		Sort:         c.Query("sort"),
		Limit:        limit,
		Offset:       offset,
	}
	results, err := h.svc.SearchProducts(c.Request.Context(), q)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"products": results, "limit": limit, "offset": offset})
}

// floatParam parses an optional float query parameter, returning nil if absent
// or unparseable.
func floatParam(c *gin.Context, key string) *float64 {
	raw := c.Query(key)
	if raw == "" {
		return nil
	}
	v, err := strconv.ParseFloat(raw, 64)
	if err != nil {
		return nil
	}
	return &v
}

// csvParam reads a repeatable param that may also be comma-joined
// (dietary=a&dietary=b or dietary=a,b), returning the flattened, trimmed list.
func csvParam(c *gin.Context, key string) []string {
	var out []string
	for _, raw := range c.QueryArray(key) {
		for _, part := range strings.Split(raw, ",") {
			if p := strings.TrimSpace(part); p != "" {
				out = append(out, p)
			}
		}
	}
	return out
}

// boolParam parses an optional boolean query parameter (true/1), nil if absent.
func boolParam(c *gin.Context, key string) *bool {
	raw := c.Query(key)
	if raw == "" {
		return nil
	}
	v := raw == "true" || raw == "1"
	return &v
}

// paging reads limit/offset query parameters with sane bounds.
func paging(c *gin.Context) (limit, offset int) {
	limit, _ = strconv.Atoi(c.Query("limit"))
	if limit <= 0 || limit > maxPageSize {
		limit = defaultPageSize
	}
	offset, _ = strconv.Atoi(c.Query("offset"))
	if offset < 0 {
		offset = 0
	}
	return limit, offset
}
