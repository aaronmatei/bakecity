package users

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/internal/middleware"
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
	u, err := h.svc.GetMe(c.Request.Context(), middleware.UserIDFromContext(c))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, u)
}

// UpdateMe handles PATCH /me.
func (h *Handler) UpdateMe(c *gin.Context) {
	var req UpdateMeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	u, err := h.svc.UpdateMe(c.Request.Context(), middleware.UserIDFromContext(c), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, u)
}
