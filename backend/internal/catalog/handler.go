package catalog

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/internal/middleware"
	"github.com/corebalt/bakecity/pkg"
)

const (
	defaultPageSize = 20
	maxPageSize     = 100
)

// Handler exposes catalog HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterPublicRoutes wires read-only catalog browsing (no auth required).
func (h *Handler) RegisterPublicRoutes(rg *gin.RouterGroup) {
	rg.GET("/products", h.ListProducts)
	rg.GET("/products/:id", h.GetProduct)
	rg.GET("/categories", h.ListCategories)
}

// RegisterRoutes wires catalog mutations (authed group).
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/products", h.CreateProduct)
	rg.PATCH("/products/:id", h.UpdateProduct)
	rg.POST("/categories", h.CreateCategory)
}

func actorFrom(c *gin.Context) Actor {
	return Actor{
		UserID:  middleware.UserIDFromContext(c),
		IsAdmin: middleware.RoleMaskFromContext(c)&middleware.RoleAdmin != 0,
	}
}

// ListProducts handles GET /products.
func (h *Handler) ListProducts(c *gin.Context) {
	limit, _ := strconv.Atoi(c.Query("limit"))
	if limit <= 0 || limit > maxPageSize {
		limit = defaultPageSize
	}
	offset, _ := strconv.Atoi(c.Query("offset"))
	if offset < 0 {
		offset = 0
	}
	f := ProductFilter{
		BakerID:    c.Query("baker_id"),
		CategoryID: c.Query("category_id"),
		Active:     c.Query("active"),
		Limit:      limit,
		Offset:     offset,
	}
	products, err := h.svc.ListProducts(c.Request.Context(), f)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"products": products, "limit": limit, "offset": offset})
}

// GetProduct handles GET /products/:id.
func (h *Handler) GetProduct(c *gin.Context) {
	p, err := h.svc.GetProduct(c.Request.Context(), c.Param("id"))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, p)
}

// CreateProduct handles POST /products.
func (h *Handler) CreateProduct(c *gin.Context) {
	var req CreateProductRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	p, err := h.svc.CreateProduct(c.Request.Context(), middleware.UserIDFromContext(c), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.Created(c, p)
}

// UpdateProduct handles PATCH /products/:id.
func (h *Handler) UpdateProduct(c *gin.Context) {
	var req UpdateProductRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	p, err := h.svc.UpdateProduct(c.Request.Context(), actorFrom(c), c.Param("id"), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, p)
}

// ListCategories handles GET /categories.
func (h *Handler) ListCategories(c *gin.Context) {
	cats, err := h.svc.ListCategories(c.Request.Context())
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"categories": cats})
}

// CreateCategory handles POST /categories (admin only).
func (h *Handler) CreateCategory(c *gin.Context) {
	var req CreateCategoryRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	cat, err := h.svc.CreateCategory(c.Request.Context(), actorFrom(c), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.Created(c, cat)
}
