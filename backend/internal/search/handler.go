package search

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes search HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the search routes.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/search/bakers", h.Bakers)
	rg.GET("/search/products", h.Products)
}

// Bakers handles GET /search/bakers.
func (h *Handler) Bakers(c *gin.Context) {
	pkg.NotImplemented(c)
}

// Products handles GET /search/products.
func (h *Handler) Products(c *gin.Context) {
	pkg.NotImplemented(c)
}
