package media

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/internal/middleware"
	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes media HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the media routes (authed group).
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/media/presign", h.Presign)
	rg.POST("/media/:id/complete", h.Complete)
}

func actorFrom(c *gin.Context) Actor {
	return Actor{
		UserID:  middleware.UserIDFromContext(c),
		IsAdmin: middleware.RoleMaskFromContext(c)&middleware.RoleAdmin != 0,
	}
}

// Presign handles POST /media/presign.
func (h *Handler) Presign(c *gin.Context) {
	var req PresignRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	res, err := h.svc.Presign(c.Request.Context(), middleware.UserIDFromContext(c), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.Created(c, res)
}

// Complete handles POST /media/:id/complete.
func (h *Handler) Complete(c *gin.Context) {
	m, err := h.svc.Complete(c.Request.Context(), actorFrom(c), c.Param("id"))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, m)
}
