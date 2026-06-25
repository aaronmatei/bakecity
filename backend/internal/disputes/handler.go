package disputes

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes disputes HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the disputes routes.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/orders/:id/disputes", h.Create)
}

// Create handles POST /orders/:id/disputes.
func (h *Handler) Create(c *gin.Context) {
	pkg.NotImplemented(c)
}
