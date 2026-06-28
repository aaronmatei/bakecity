package production

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/internal/middleware"
	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes production HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the production routes (authed group).
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/orders/:id/production", h.List)
	rg.POST("/orders/:id/production", h.Create)
}

func actorFrom(c *gin.Context) Actor {
	return Actor{
		UserID:  middleware.UserIDFromContext(c),
		IsAdmin: middleware.RoleMaskFromContext(c)&middleware.RoleAdmin != 0,
	}
}

// Create handles POST /orders/:id/production.
func (h *Handler) Create(c *gin.Context) {
	var req CreateUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	u, err := h.svc.Add(c.Request.Context(), actorFrom(c), c.Param("id"), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.Created(c, u)
}

// List handles GET /orders/:id/production.
func (h *Handler) List(c *gin.Context) {
	updates, err := h.svc.List(c.Request.Context(), actorFrom(c), c.Param("id"))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"updates": updates})
}
