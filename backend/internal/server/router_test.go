package server

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/corebalt/bakecity/internal/config"
)

// TestNewRouterRegistersRoutes builds the full router with no backing services
// (nil DB/Redis). It asserts route registration does not panic — catching
// conflicting/overlapping route definitions across domains — and that the
// health endpoint responds.
func TestNewRouterRegistersRoutes(t *testing.T) {
	r := New(Deps{Cfg: &config.Config{Env: "test"}})
	if r == nil {
		t.Fatal("New returned nil engine")
	}

	rec := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	r.ServeHTTP(rec, req)
	if rec.Code != http.StatusOK {
		t.Fatalf("GET /health = %d, want 200", rec.Code)
	}
}
