package orders

import (
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/internal/middleware"
	"github.com/corebalt/bakecity/pkg"
)

const (
	defaultPageSize = 20
	maxPageSize     = 100
)

// Handler exposes order HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires order routes (authed group).
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/orders", h.Create)
	rg.GET("/orders", h.List)
	rg.GET("/orders/insights", h.Insights)
	rg.GET("/orders/:id", h.Get)
	rg.POST("/orders/:id/cancel", h.Cancel)
}

// Insights handles GET /orders/insights (the signed-in baker's summary).
func (h *Handler) Insights(c *gin.Context) {
	res, err := h.svc.BakerInsights(c.Request.Context(), actorFrom(c))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, res)
}

func actorFrom(c *gin.Context) Actor {
	return Actor{
		UserID:  middleware.UserIDFromContext(c),
		IsAdmin: middleware.RoleMaskFromContext(c)&middleware.RoleAdmin != 0,
	}
}

// Create handles POST /orders.
func (h *Handler) Create(c *gin.Context) {
	var req CreateOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	o, err := h.svc.Create(c.Request.Context(), middleware.UserIDFromContext(c), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.Created(c, o)
}

// List handles GET /orders.
func (h *Handler) List(c *gin.Context) {
	limit, _ := strconv.Atoi(c.Query("limit"))
	if limit <= 0 || limit > maxPageSize {
		limit = defaultPageSize
	}
	offset, _ := strconv.Atoi(c.Query("offset"))
	if offset < 0 {
		offset = 0
	}
	f := ListFilter{
		Role:   c.Query("role"),
		Status: c.Query("status"),
		Limit:  limit,
		Offset: offset,
	}
	orders, err := h.svc.List(c.Request.Context(), actorFrom(c), f)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"orders": orders, "limit": limit, "offset": offset})
}

// Get handles GET /orders/:id.
func (h *Handler) Get(c *gin.Context) {
	o, err := h.svc.Get(c.Request.Context(), actorFrom(c), c.Param("id"))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, o)
}

// Cancel handles POST /orders/:id/cancel.
func (h *Handler) Cancel(c *gin.Context) {
	o, err := h.svc.Cancel(c.Request.Context(), actorFrom(c), c.Param("id"))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, o)
}
