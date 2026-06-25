package quotes

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes quotes HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the quotes routes.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/orders/:id/quotes", h.Create)
	rg.POST("/orders/:id/quotes/:qid/accept", h.Accept)
}

// Create handles POST /orders/:id/quotes.
func (h *Handler) Create(c *gin.Context) {
	pkg.NotImplemented(c)
}

// Accept handles POST /orders/:id/quotes/:qid/accept.
func (h *Handler) Accept(c *gin.Context) {
	pkg.NotImplemented(c)
}
