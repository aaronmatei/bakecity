package payments

import (
	"context"
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/internal/middleware"
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
	rg.GET("/payouts/balance", h.PayoutBalance)
	rg.POST("/payouts", h.RequestPayout)
}

// RegisterPublicRoutes wires the PSP webhook (no auth; verified by signature).
func (h *Handler) RegisterPublicRoutes(rg *gin.RouterGroup) {
	rg.POST("/payments/webhook", h.Webhook)
}

func actorFrom(c *gin.Context) Actor {
	return Actor{
		UserID:  middleware.UserIDFromContext(c),
		IsAdmin: middleware.RoleMaskFromContext(c)&middleware.RoleAdmin != 0,
	}
}

// initiateFn is the shared shape of InitiateDeposit/InitiateBalance.
type initiateFn func(ctx context.Context, actor Actor, orderID, idemKey, phone string) (*Payment, error)

// Deposit handles POST /orders/:id/payments/deposit (idempotent).
func (h *Handler) Deposit(c *gin.Context) { h.collect(c, h.svc.InitiateDeposit) }

// Balance handles POST /orders/:id/payments/balance (idempotent).
func (h *Handler) Balance(c *gin.Context) { h.collect(c, h.svc.InitiateBalance) }

func (h *Handler) collect(c *gin.Context, fn initiateFn) {
	var req CollectRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	payment, err := fn(c.Request.Context(), actorFrom(c), c.Param("id"), c.GetHeader("Idempotency-Key"), req.Phone)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.Created(c, payment)
}

// PayoutBalance handles GET /payouts/balance (caller's baker ledger position).
func (h *Handler) PayoutBalance(c *gin.Context) {
	summary, err := h.svc.BakerBalance(c.Request.Context(), actorFrom(c))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, summary)
}

// RequestPayout handles POST /payouts: disburse the caller-baker's available
// balance (idempotent per baker via the Idempotency-Key header).
func (h *Handler) RequestPayout(c *gin.Context) {
	payout, err := h.svc.RequestPayout(c.Request.Context(), actorFrom(c), c.GetHeader("Idempotency-Key"))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.Created(c, payout)
}

// Webhook handles POST /payments/webhook (idempotent, signature-verified).
func (h *Handler) Webhook(c *gin.Context) {
	body, err := c.GetRawData()
	if err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, "could not read body")
		return
	}
	status, err := h.svc.HandleWebhook(c.Request.Context(), c.GetHeader("X-PSP-Signature"), body)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"status": status})
}
