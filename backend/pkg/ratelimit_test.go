package pkg

import (
	"context"
	"testing"
	"time"
)

// TestRateLimiterFailsOpenWithoutRedis ensures a nil client never blocks (so a
// Redis outage degrades to no limiting rather than a hard failure).
func TestRateLimiterFailsOpenWithoutRedis(t *testing.T) {
	rl := NewRateLimiter(nil)
	allowed, remaining, retryAfter, err := rl.Allow(context.Background(), "k", 5, time.Minute)
	if err != nil {
		t.Fatalf("err = %v, want nil", err)
	}
	if !allowed {
		t.Error("want allowed=true without Redis")
	}
	if remaining != 5 {
		t.Errorf("remaining = %d, want 5", remaining)
	}
	if retryAfter != 0 {
		t.Errorf("retryAfter = %v, want 0", retryAfter)
	}
}
