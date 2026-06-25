package bakers

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes bakers HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the bakers routes.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/bakers", h.Create)
	rg.PATCH("/bakers/:id", h.Update)
	rg.POST("/bakers/:id/verify", h.Verify)
	rg.GET("/bakers/:id/availability", h.GetAvailability)
	rg.PUT("/bakers/:id/availability", h.SetAvailability)
}

// Create handles POST /bakers.
func (h *Handler) Create(c *gin.Context) {
	pkg.NotImplemented(c)
}

// Update handles PATCH /bakers/:id.
func (h *Handler) Update(c *gin.Context) {
	pkg.NotImplemented(c)
}

// Verify handles POST /bakers/:id/verify.
func (h *Handler) Verify(c *gin.Context) {
	pkg.NotImplemented(c)
}

// GetAvailability handles GET /bakers/:id/availability.
func (h *Handler) GetAvailability(c *gin.Context) {
	pkg.NotImplemented(c)
}

// SetAvailability handles PUT /bakers/:id/availability.
func (h *Handler) SetAvailability(c *gin.Context) {
	pkg.NotImplemented(c)
}
