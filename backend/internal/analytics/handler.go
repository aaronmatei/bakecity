package analytics

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes analytics HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the analytics routes.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/analytics/overview", h.Overview)
}

// Overview handles GET /analytics/overview.
func (h *Handler) Overview(c *gin.Context) {
	stats, err := h.svc.Overview(c.Request.Context())
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, stats)
}
