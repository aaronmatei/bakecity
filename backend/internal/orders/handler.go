package orders

import (
	"errors"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/internal/middleware"
	"github.com/corebalt/bakecity/pkg"
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
	rg.GET("/orders/:id", h.Get)
}

// Create handles POST /orders.
func (h *Handler) Create(c *gin.Context) {
	var req CreateOrderRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	customerID := middleware.UserIDFromContext(c)
	id, err := h.svc.Create(c.Request.Context(), customerID, req)
	if err != nil {
		if errors.Is(err, pkg.ErrNotImplemented) {
			pkg.NotImplemented(c)
			return
		}
		pkg.Error(c, http.StatusInternalServerError, pkg.ErrCodeInternal, err.Error())
		return
	}
	pkg.Created(c, gin.H{"id": id})
}

// Get handles GET /orders/:id.
func (h *Handler) Get(c *gin.Context) {
	o, err := h.svc.Get(c.Request.Context(), c.Param("id"))
	if err != nil {
		switch {
		case errors.Is(err, pkg.ErrNotFound):
			pkg.Error(c, http.StatusNotFound, pkg.ErrCodeNotFound, "order not found")
		case errors.Is(err, pkg.ErrNotImplemented):
			pkg.NotImplemented(c)
		default:
			pkg.Error(c, http.StatusInternalServerError, pkg.ErrCodeInternal, err.Error())
		}
		return
	}
	pkg.OK(c, o)
}
