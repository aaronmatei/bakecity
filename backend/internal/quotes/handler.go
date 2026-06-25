package quotes

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/internal/middleware"
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

// RegisterRoutes wires the quotes routes (authed group).
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/orders/:id/quotes", h.List)
	rg.POST("/orders/:id/quotes", h.Create)
	rg.POST("/orders/:id/quotes/:qid/accept", h.Accept)
}

func actorFrom(c *gin.Context) Actor {
	return Actor{
		UserID:  middleware.UserIDFromContext(c),
		IsAdmin: middleware.RoleMaskFromContext(c)&middleware.RoleAdmin != 0,
	}
}

// List handles GET /orders/:id/quotes.
func (h *Handler) List(c *gin.Context) {
	quotes, err := h.svc.List(c.Request.Context(), actorFrom(c), c.Param("id"))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"quotes": quotes})
}

// Create handles POST /orders/:id/quotes.
func (h *Handler) Create(c *gin.Context) {
	var req CreateQuoteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	q, err := h.svc.Propose(c.Request.Context(), actorFrom(c), c.Param("id"), req)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.Created(c, q)
}

// Accept handles POST /orders/:id/quotes/:qid/accept.
func (h *Handler) Accept(c *gin.Context) {
	order, quote, err := h.svc.Accept(c.Request.Context(), actorFrom(c), c.Param("id"), c.Param("qid"))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"order": order, "quote": quote})
}
