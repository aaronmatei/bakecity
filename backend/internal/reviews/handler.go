package reviews

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes reviews HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the reviews routes.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/reviews", h.Create)
}

// Create handles POST /reviews.
func (h *Handler) Create(c *gin.Context) {
	pkg.NotImplemented(c)
}
