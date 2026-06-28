package admin

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

// Handler exposes admin HTTP endpoints (mounted behind RequireRole(admin)).
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires admin routes under an already role-guarded group.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/admin/bakers/pending", h.PendingBakers)
	rg.POST("/admin/bakers/:id/approve", h.ApproveBaker)
	rg.GET("/admin/disputes", h.ListDisputes)
	rg.POST("/admin/disputes/:id/resolve", h.ResolveDispute)
	rg.POST("/admin/orders/:id/refund", h.RefundOrder)
}

// PendingBakers handles GET /admin/bakers/pending.
func (h *Handler) PendingBakers(c *gin.Context) {
	bakers, err := h.svc.PendingBakers(c.Request.Context())
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"bakers": bakers})
}

// ApproveBaker handles POST /admin/bakers/:id/approve.
func (h *Handler) ApproveBaker(c *gin.Context) {
	baker, err := h.svc.ApproveBaker(c.Request.Context(), c.Param("id"))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, baker)
}

// ListDisputes handles GET /admin/disputes.
func (h *Handler) ListDisputes(c *gin.Context) {
	limit, _ := strconv.Atoi(c.Query("limit"))
	if limit <= 0 || limit > maxPageSize {
		limit = defaultPageSize
	}
	offset, _ := strconv.Atoi(c.Query("offset"))
	if offset < 0 {
		offset = 0
	}
	ds, err := h.svc.ListDisputes(c.Request.Context(), c.Query("status"), limit, offset)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"disputes": ds})
}

// ResolveDispute handles POST /admin/disputes/:id/resolve.
func (h *Handler) ResolveDispute(c *gin.Context) {
	var req ResolveDisputeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	d, err := h.svc.ResolveDispute(c.Request.Context(), middleware.UserIDFromContext(c), c.Param("id"), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, d)
}

// RefundOrder handles POST /admin/orders/:id/refund.
func (h *Handler) RefundOrder(c *gin.Context) {
	var req RefundRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	order, refunded, err := h.svc.RefundOrder(c.Request.Context(), c.Param("id"), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"order": order, "refunded": refunded})
}
