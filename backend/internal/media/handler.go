package media

import (
	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes media HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the media routes.
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/media/presign", h.Presign)
}

// Presign handles POST /media/presign.
func (h *Handler) Presign(c *gin.Context) {
	pkg.NotImplemented(c)
}
