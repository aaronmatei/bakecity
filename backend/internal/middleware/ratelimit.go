package middleware

import (
	"context"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"

	"github.com/corebalt/bakecity/pkg"
)

// Limiter is the rate-limiting backend (implemented by pkg.RateLimiter).
type Limiter interface {
	Allow(ctx context.Context, key string, limit int, window time.Duration) (allowed bool, remaining int, retryAfter time.Duration, err error)
}

// RateLimit returns middleware allowing up to limit requests per window per key
// (computed by keyFn, namespaced by scope). It sets X-RateLimit-* headers, and
// on breach returns 429 with Retry-After. It fails open if the backend errors,
// so a Redis outage degrades to no limiting rather than an outage.
func RateLimit(l Limiter, scope string, limit int, window time.Duration, keyFn func(*gin.Context) string) gin.HandlerFunc {
	return func(c *gin.Context) {
		allowed, remaining, retryAfter, err := l.Allow(c.Request.Context(), scope+":"+keyFn(c), limit, window)
		if err != nil {
			c.Next() // fail open
			return
		}
		c.Header("X-RateLimit-Limit", strconv.Itoa(limit))
		c.Header("X-RateLimit-Remaining", strconv.Itoa(remaining))
		if !allowed {
			c.Header("Retry-After", strconv.Itoa(int(retryAfter.Seconds())+1))
			pkg.Error(c, http.StatusTooManyRequests, pkg.ErrCodeRateLimited, "rate limit exceeded")
			return
		}
		c.Next()
	}
}

// ClientIP keys a limiter by the request's client IP.
func ClientIP(c *gin.Context) string { return c.ClientIP() }
