package favorites

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/internal/middleware"
	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes wishlist HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the favorites routes (authed group).
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/favorites", h.List)
	rg.PUT("/favorites/:productId", h.Add)
	rg.DELETE("/favorites/:productId", h.Remove)
}

// List handles GET /favorites.
func (h *Handler) List(c *gin.Context) {
	ids, err := h.svc.List(c.Request.Context(), middleware.UserIDFromContext(c))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"product_ids": ids})
}

// Add handles PUT /favorites/:productId.
func (h *Handler) Add(c *gin.Context) {
	if err := h.svc.Add(c.Request.Context(), middleware.UserIDFromContext(c), c.Param("productId")); err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"ok": true})
}

// Remove handles DELETE /favorites/:productId.
func (h *Handler) Remove(c *gin.Context) {
	if err := h.svc.Remove(c.Request.Context(), middleware.UserIDFromContext(c), c.Param("productId")); err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"ok": true})
}
