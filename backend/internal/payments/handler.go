package payments

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes payment HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires payment routes that require authentication.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/orders/:id/payments/deposit", h.Deposit)
	rg.POST("/orders/:id/payments/balance", h.Balance)
}

// RegisterPublicRoutes wires the PSP webhook (no auth; verified by signature).
func (h *Handler) RegisterPublicRoutes(rg *gin.RouterGroup) {
	rg.POST("/payments/webhook", h.Webhook)
}

// Deposit handles POST /orders/:id/payments/deposit (idempotent).
func (h *Handler) Deposit(c *gin.Context) {
	pkg.NotImplemented(c)
}

// Balance handles POST /orders/:id/payments/balance (idempotent).
func (h *Handler) Balance(c *gin.Context) {
	pkg.NotImplemented(c)
}

// Webhook handles POST /payments/webhook (idempotent, signature-verified).
func (h *Handler) Webhook(c *gin.Context) {
	pkg.NotImplemented(c)
}
