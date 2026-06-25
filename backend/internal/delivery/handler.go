package delivery

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes delivery HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the delivery routes.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/orders/:id/delivery/dispatch", h.Dispatch)
	rg.POST("/orders/:id/delivery/confirm", h.Confirm)
}

// Dispatch handles POST /orders/:id/delivery/dispatch.
func (h *Handler) Dispatch(c *gin.Context) {
	pkg.NotImplemented(c)
}

// Confirm handles POST /orders/:id/delivery/confirm.
func (h *Handler) Confirm(c *gin.Context) {
	pkg.NotImplemented(c)
}
