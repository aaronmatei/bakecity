package users

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes users HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the users routes.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/me", h.GetMe)
	rg.PATCH("/me", h.UpdateMe)
}

// GetMe handles GET /me.
func (h *Handler) GetMe(c *gin.Context) {
	pkg.NotImplemented(c)
}

// UpdateMe handles PATCH /me.
func (h *Handler) UpdateMe(c *gin.Context) {
	pkg.NotImplemented(c)
}
