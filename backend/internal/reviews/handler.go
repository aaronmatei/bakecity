package reviews

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

// Handler exposes reviews HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the reviews routes (authed group).
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/reviews", h.Create)
	rg.GET("/orders/:id/review", h.GetForOrder)
	rg.GET("/bakers/:id/reviews", h.ListForBaker)
}

func actorFrom(c *gin.Context) Actor {
	return Actor{
		UserID:  middleware.UserIDFromContext(c),
		IsAdmin: middleware.RoleMaskFromContext(c)&middleware.RoleAdmin != 0,
	}
}

// Create handles POST /reviews.
func (h *Handler) Create(c *gin.Context) {
	var req CreateReviewRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	rev, err := h.svc.Create(c.Request.Context(), actorFrom(c), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.Created(c, rev)
}

// GetForOrder handles GET /orders/:id/review.
func (h *Handler) GetForOrder(c *gin.Context) {
	rev, err := h.svc.GetForOrder(c.Request.Context(), actorFrom(c), c.Param("id"))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, rev)
}

// ListForBaker handles GET /bakers/:id/reviews.
func (h *Handler) ListForBaker(c *gin.Context) {
	limit, _ := strconv.Atoi(c.Query("limit"))
	if limit <= 0 || limit > maxPageSize {
		limit = defaultPageSize
	}
	offset, _ := strconv.Atoi(c.Query("offset"))
	if offset < 0 {
		offset = 0
	}
	res, err := h.svc.ListForBaker(c.Request.Context(), c.Param("id"), limit, offset)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, res)
}
