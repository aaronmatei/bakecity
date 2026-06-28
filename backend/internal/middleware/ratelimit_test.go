package middleware

import (
	"context"
	"errors"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

type fakeLimiter struct {
	allowed    bool
	remaining  int
	retryAfter time.Duration
	err        error
	gotKey     string
}

func (f *fakeLimiter) Allow(_ context.Context, key string, _ int, _ time.Duration) (bool, int, time.Duration, error) {
	f.gotKey = key
	return f.allowed, f.remaining, f.retryAfter, f.err
}

func runWith(l Limiter) *httptest.ResponseRecorder {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(RateLimit(l, "ip", 10, time.Minute, func(*gin.Context) string { return "1.2.3.4" }))
	r.GET("/x", func(c *gin.Context) { c.String(http.StatusOK, "ok") })
	rec := httptest.NewRecorder()
	r.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, "/x", nil))
	return rec
}

func TestRateLimitAllows(t *testing.T) {
	fl := &fakeLimiter{allowed: true, remaining: 7}
	rec := runWith(fl)
	if rec.Code != http.StatusOK {
		t.Fatalf("got %d, want 200", rec.Code)
	}
	if fl.gotKey != "ip:1.2.3.4" {
		t.Errorf("key = %q, want ip:1.2.3.4", fl.gotKey)
	}
	if rec.Header().Get("X-RateLimit-Limit") != "10" || rec.Header().Get("X-RateLimit-Remaining") != "7" {
		t.Errorf("headers = %q/%q", rec.Header().Get("X-RateLimit-Limit"), rec.Header().Get("X-RateLimit-Remaining"))
	}
}

func TestRateLimitBlocks(t *testing.T) {
	rec := runWith(&fakeLimiter{allowed: false, remaining: 0, retryAfter: 30 * time.Second})
	if rec.Code != http.StatusTooManyRequests {
		t.Fatalf("got %d, want 429", rec.Code)
	}
	if rec.Header().Get("Retry-After") == "" {
		t.Error("missing Retry-After header")
	}
	if !strings.Contains(rec.Body.String(), "RATE_LIMITED") {
		t.Errorf("body = %s", rec.Body.String())
	}
}

func TestRateLimitFailsOpenOnError(t *testing.T) {
	rec := runWith(&fakeLimiter{err: errors.New("redis down")})
	if rec.Code != http.StatusOK {
		t.Fatalf("got %d, want 200 (fail open)", rec.Code)
	}
}
