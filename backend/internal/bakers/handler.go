package bakers

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/internal/middleware"
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

// actorFrom builds an Actor from the authenticated request context.
func actorFrom(c *gin.Context) Actor {
	return Actor{
		UserID:  middleware.UserIDFromContext(c),
		IsAdmin: middleware.RoleMaskFromContext(c)&middleware.RoleAdmin != 0,
	}
}

// Create handles POST /bakers.
func (h *Handler) Create(c *gin.Context) {
	var req CreateBakerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	profile, err := h.svc.Create(c.Request.Context(), middleware.UserIDFromContext(c), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.Created(c, profile)
}

// Update handles PATCH /bakers/:id.
func (h *Handler) Update(c *gin.Context) {
	var req UpdateBakerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	profile, err := h.svc.Update(c.Request.Context(), actorFrom(c), c.Param("id"), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, profile)
}

// Verify handles POST /bakers/:id/verify (KYC submission).
func (h *Handler) Verify(c *gin.Context) {
	profile, err := h.svc.SubmitKYC(c.Request.Context(), actorFrom(c), c.Param("id"))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, profile)
}

// GetAvailability handles GET /bakers/:id/availability.
func (h *Handler) GetAvailability(c *gin.Context) {
	avail, err := h.svc.GetAvailability(c.Request.Context(), c.Param("id"))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, avail)
}

// SetAvailability handles PUT /bakers/:id/availability.
func (h *Handler) SetAvailability(c *gin.Context) {
	var req AvailabilityRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	avail, err := h.svc.SetAvailability(c.Request.Context(), actorFrom(c), c.Param("id"), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, avail)
}
