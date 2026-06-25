package messaging

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/internal/middleware"
	"github.com/corebalt/bakecity/pkg"
)

const (
	defaultPageSize = 50
	maxPageSize     = 200
)

// Handler exposes messaging HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the messaging routes (authed group).
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/orders/:id/messages", h.List)
	rg.POST("/orders/:id/messages", h.Send)
}

func actorFrom(c *gin.Context) Actor {
	return Actor{
		UserID:  middleware.UserIDFromContext(c),
		IsAdmin: middleware.RoleMaskFromContext(c)&middleware.RoleAdmin != 0,
	}
}

// List handles GET /orders/:id/messages.
func (h *Handler) List(c *gin.Context) {
	limit, _ := strconv.Atoi(c.Query("limit"))
	if limit <= 0 || limit > maxPageSize {
		limit = defaultPageSize
	}
	offset, _ := strconv.Atoi(c.Query("offset"))
	if offset < 0 {
		offset = 0
	}
	msgs, err := h.svc.List(c.Request.Context(), actorFrom(c), c.Param("id"), limit, offset)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"messages": msgs, "limit": limit, "offset": offset})
}

// Send handles POST /orders/:id/messages.
func (h *Handler) Send(c *gin.Context) {
	var req SendMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	m, err := h.svc.Send(c.Request.Context(), actorFrom(c), c.Param("id"), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.Created(c, m)
}
