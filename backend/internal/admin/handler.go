package admin

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
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
func (h *Handler) ListDisputes(c *gin.Context) { pkg.NotImplemented(c) }

// ResolveDispute handles POST /admin/disputes/:id/resolve.
func (h *Handler) ResolveDispute(c *gin.Context) { pkg.NotImplemented(c) }

// RefundOrder handles POST /admin/orders/:id/refund.
func (h *Handler) RefundOrder(c *gin.Context) { pkg.NotImplemented(c) }
