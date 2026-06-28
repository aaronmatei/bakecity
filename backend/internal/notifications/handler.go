package notifications

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/internal/middleware"
	"github.com/corebalt/bakecity/pkg"
)

const (
	defaultPageSize = 20
	maxPageSize     = 100
)

// Handler exposes notifications HTTP endpoints.
type Handler struct {
	svc       *Service
	hub       *Hub
	jwtSecret string
}

// NewHandler constructs a Handler.
func NewHandler(svc *Service, hub *Hub, jwtSecret string) *Handler {
	return &Handler{svc: svc, hub: hub, jwtSecret: jwtSecret}
}

// RegisterRoutes wires the notifications REST routes (authed group).
func (h *Handler) RegisterRoutes(rg *gin.RouterGroup) {
	rg.GET("/notifications", h.List)
	rg.GET("/notifications/unread-count", h.UnreadCount)
	rg.POST("/notifications/read-all", h.MarkAllRead)
	rg.POST("/notifications/:id/read", h.MarkRead)
}

// RegisterPublicRoutes wires the WebSocket endpoint. It is mounted without the
// Auth middleware because a browser cannot set the Authorization header on a
// WebSocket handshake; the token is taken from the `token` query param (or a
// bearer header for non-browser clients) and verified here.
func (h *Handler) RegisterPublicRoutes(rg *gin.RouterGroup) {
	rg.GET("/ws/notifications", h.ServeWS)
}

// ServeWS authenticates the request and upgrades it to a WebSocket that streams
// the user's notifications in realtime.
func (h *Handler) ServeWS(c *gin.Context) {
	token := c.Query("token")
	if token == "" {
		token = strings.TrimPrefix(c.GetHeader("Authorization"), "Bearer ")
	}
	userID, _, err := middleware.ParseToken(h.jwtSecret, token)
	if err != nil || userID == "" {
		pkg.Error(c, http.StatusUnauthorized, pkg.ErrCodeUnauthorized, "invalid token")
		return
	}
	// On success the response is hijacked; nothing more to write here.
	_ = h.hub.Serve(c.Writer, c.Request, userID)
}

// List handles GET /notifications (?unread=true&limit&offset).
func (h *Handler) List(c *gin.Context) {
	limit, _ := strconv.Atoi(c.Query("limit"))
	if limit <= 0 || limit > maxPageSize {
		limit = defaultPageSize
	}
	offset, _ := strconv.Atoi(c.Query("offset"))
	if offset < 0 {
		offset = 0
	}
	unreadOnly := c.Query("unread") == "true"

	items, err := h.svc.List(c.Request.Context(), middleware.UserIDFromContext(c), unreadOnly, limit, offset)
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"notifications": items, "limit": limit, "offset": offset})
}

// UnreadCount handles GET /notifications/unread-count.
func (h *Handler) UnreadCount(c *gin.Context) {
	n, err := h.svc.UnreadCount(c.Request.Context(), middleware.UserIDFromContext(c))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"unread": n})
}

// MarkRead handles POST /notifications/:id/read.
func (h *Handler) MarkRead(c *gin.Context) {
	if err := h.svc.MarkRead(c.Request.Context(), middleware.UserIDFromContext(c), c.Param("id")); err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.NoContent(c)
}

// MarkAllRead handles POST /notifications/read-all.
func (h *Handler) MarkAllRead(c *gin.Context) {
	n, err := h.svc.MarkAllRead(c.Request.Context(), middleware.UserIDFromContext(c))
	if err != nil {
		pkg.WriteError(c, err)
		return
	}
	pkg.OK(c, gin.H{"marked_read": n})
}
