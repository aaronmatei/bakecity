package notifications

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes notifications HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the notifications routes.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/notifications", h.List)
}

// List handles GET /notifications.
func (h *Handler) List(c *gin.Context) {
	pkg.NotImplemented(c)
}
