package auth

import (
	"net/http"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Handler exposes authentication HTTP endpoints.
type Handler struct {
	svc *Service
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service) *Handler {
	return &Handler{svc: svc}
}

// RegisterRoutes wires the auth routes (public).
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.POST("/auth/register", h.Register)
	rg.POST("/auth/login", h.Login)
}

// Register handles POST /auth/register.
func (h *Handler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	resp, err := h.svc.Register(c.Request.Context(), req)
	if err != nil {
		writeErr(c, err)
		return
	}
	pkg.Created(c, resp)
}

// Login handles POST /auth/login.
func (h *Handler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		pkg.Error(c, http.StatusBadRequest, pkg.ErrCodeBadRequest, err.Error())
		return
	}
	resp, err := h.svc.Login(c.Request.Context(), req)
	if err != nil {
		writeErr(c, err)
		return
	}
	pkg.OK(c, resp)
}

func writeErr(c *gin.Context, err error) {
	if apiErr, ok := err.(*pkg.APIError); ok {
		pkg.FromAPIError(c, apiErr)
		return
	}
	pkg.Error(c, http.StatusInternalServerError, pkg.ErrCodeInternal, err.Error())
}
