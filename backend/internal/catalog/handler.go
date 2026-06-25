package catalog

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes catalog HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the catalog routes.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/products", h.ListProducts)
	rg.POST("/products", h.CreateProduct)
	rg.GET("/categories", h.ListCategories)
}

// ListProducts handles GET /products.
func (h *Handler) ListProducts(c *gin.Context) {
	pkg.NotImplemented(c)
}

// CreateProduct handles POST /products.
func (h *Handler) CreateProduct(c *gin.Context) {
	pkg.NotImplemented(c)
}

// ListCategories handles GET /categories.
func (h *Handler) ListCategories(c *gin.Context) {
	pkg.NotImplemented(c)
}
