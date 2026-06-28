package delivery

import (
	"errors"
	"io"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/internal/middleware"
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

// RegisterRoutes wires the delivery routes (authed group).
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/orders/:id/delivery", h.Get)
	rg.POST("/orders/:id/delivery/dispatch", h.Dispatch)
	rg.POST("/orders/:id/delivery/confirm", h.Confirm)
}

func actorFrom(c *gin.Context) Actor {
	return Actor{
		UserID:  middleware.UserIDFromContext(c),
		IsAdmin: middleware.RoleMaskFromContext(c)&middleware.RoleAdmin != 0,
	}
}

// Get handles GET /orders/:id/delivery.
func (h *Handler) Get(c *gin.Context) {
	d, err := h.svc.Get(c.Request.Context(), actorFrom(c), c.Param("id"))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, d)
}

// Dispatch handles POST /orders/:id/delivery/dispatch.
func (h *Handler) Dispatch(c *gin.Context) {
	var req DispatchRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	d, err := h.svc.Dispatch(c.Request.Context(), actorFrom(c), c.Param("id"), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.Created(c, d)
}

// Confirm handles POST /orders/:id/delivery/confirm.
func (h *Handler) Confirm(c *gin.Context) {
	var req ConfirmRequest
	// The body is optional (a customer may confirm with no proof); only a
	// malformed (non-empty) JSON body is an error.
	if err := c.ShouldBindJSON(&req); err != nil && !errors.Is(err, io.EOF) {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	d, err := h.svc.Confirm(c.Request.Context(), actorFrom(c), c.Param("id"), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, d)
}
