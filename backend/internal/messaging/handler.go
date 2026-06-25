package messaging

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes messaging HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the messaging routes.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/orders/:id/messages", h.List)
	rg.POST("/orders/:id/messages", h.Send)
}

// List handles GET /orders/:id/messages.
func (h *Handler) List(c *gin.Context) {
	pkg.NotImplemented(c)
}

// Send handles POST /orders/:id/messages.
func (h *Handler) Send(c *gin.Context) {
	pkg.NotImplemented(c)
}
