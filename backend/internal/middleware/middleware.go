// Package middleware contains shared Gin middleware: request IDs, recovery,
// logging, JWT auth, and role-based access control.
package middleware

import (
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"github.com/corebalt/bakecity/pkg"
)

// Context keys for values set by middleware.
const (
	ContextRequestID = "request_id"
	ContextUserID    = "user_id"
	ContextRoleMask  = "role_mask"
)

// Role bitmask values (mirrors users.role_mask).
const (
	RoleCustomer = 1
	RoleBaker    = 2
	RoleAdmin    = 4
)

// HeaderRequestID is the response/request header used to propagate request IDs.
const HeaderRequestID = "X-Request-ID"

// RequestID assigns a request ID (honoring an inbound one) and echoes it back.
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.GetHeader(HeaderRequestID)
		if id == "" {
			id = uuid.NewString()
		}
		c.Set(ContextRequestID, id)
		c.Header(HeaderRequestID, id)
		c.Next()
	}
}

// Recovery recovers from panics and returns a 500 JSON error.
func Recovery() gin.HandlerFunc {
	return gin.CustomRecovery(func(c *gin.Context, _ any) {
		pkg.Error(c, http.StatusInternalServerError, pkg.ErrCodeInternal, "internal server error")
	})
}

// Logger is a lightweight request logger built on gin's formatter.
func Logger() gin.HandlerFunc {
	return gin.LoggerWithFormatter(func(p gin.LogFormatterParams) string {
		return strings.Join([]string{
			p.TimeStamp.Format(time.RFC3339),
			p.Method,
			p.Path,
			http.StatusText(p.StatusCode),
			p.Latency.String(),
		}, " ") + "\n"
	})
}

// AuthClaims is the JWT payload BakeCity issues.
type AuthClaims struct {
	RoleMask int `json:"role_mask"`
	jwt.RegisteredClaims
}

// Auth validates a Bearer JWT signed with secret and populates the context with
// the user id and role mask.
func Auth(secret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			pkg.Error(c, http.StatusUnauthorized, pkg.ErrCodeUnauthorized, "missing bearer token")
			return
		}
		userID, roleMask, err := ParseToken(secret, strings.TrimPrefix(header, "Bearer "))
		if err != nil {
			pkg.Error(c, http.StatusUnauthorized, pkg.ErrCodeUnauthorized, "invalid token")
			return
		}

		c.Set(ContextUserID, userID)
		c.Set(ContextRoleMask, roleMask)
		c.Next()
	}
}

// ParseToken validates a signed HS256 JWT and returns its subject (user id) and
// role mask. It is shared by the Auth middleware and the WebSocket handler
// (which authenticates via a query-param token, since browsers can't set the
// Authorization header on a WebSocket handshake).
func ParseToken(secret, tokenStr string) (userID string, roleMask int, err error) {
	claims := &AuthClaims{}
	token, err := jwt.ParseWithClaims(tokenStr, claims, func(t *jwt.Token) (any, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, jwt.ErrSignatureInvalid
		}
		return []byte(secret), nil
	})
	if err != nil {
		return "", 0, err
	}
	if !token.Valid {
		return "", 0, jwt.ErrTokenInvalidClaims
	}
	return claims.Subject, claims.RoleMask, nil
}

// RequireRole aborts unless the authenticated user has at least one of the
// given role bits set in their role mask.
func RequireRole(roles ...int) gin.HandlerFunc {
	return func(c *gin.Context) {
		mask := RoleMaskFromContext(c)
		for _, r := range roles {
			if mask&r != 0 {
				c.Next()
				return
			}
		}
		pkg.Error(c, http.StatusForbidden, pkg.ErrCodeForbidden, "insufficient role")
	}
}

// UserIDFromContext returns the authenticated user id, if any.
func UserIDFromContext(c *gin.Context) string {
	if v, ok := c.Get(ContextUserID); ok {
		if s, ok := v.(string); ok {
			return s
		}
	}
	return ""
}

// RoleMaskFromContext returns the authenticated user's role mask.
func RoleMaskFromContext(c *gin.Context) int {
	if v, ok := c.Get(ContextRoleMask); ok {
		if m, ok := v.(int); ok {
			return m
		}
	}
	return 0
}
