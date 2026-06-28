package pkg

import (
	"context"
	"time"

	"github.com/redis/go-redis/v9"
)

// allowScript atomically increments a fixed-window counter, sets the window TTL
// on first hit, and returns {count, ttl_ms}. Doing it in one round trip avoids
// the race where the process dies between INCR and EXPIRE, leaving a key with
// no expiry.
var allowScript = redis.NewScript(`
local c = redis.call('INCR', KEYS[1])
if c == 1 then
  redis.call('PEXPIRE', KEYS[1], ARGV[1])
end
return {c, redis.call('PTTL', KEYS[1])}
`)

// RateLimiter is a Redis-backed fixed-window rate limiter.
type RateLimiter struct {
	rdb *redis.Client
}

// NewRateLimiter constructs a RateLimiter. A nil client disables limiting (Allow
// fails open).
func NewRateLimiter(rdb *redis.Client) *RateLimiter {
	return &RateLimiter{rdb: rdb}
}

// Allow records a request against key and reports whether it is within limit for
// the current window. It returns the remaining allowance and, when blocked, how
// long until the window resets. With no Redis client it always allows.
func (r *RateLimiter) Allow(ctx context.Context, key string, limit int, window time.Duration) (allowed bool, remaining int, retryAfter time.Duration, err error) {
	if r == nil || r.rdb == nil {
		return true, limit, 0, nil
	}
	res, err := allowScript.Run(ctx, r.rdb, []string{"rl:" + key}, window.Milliseconds()).Slice()
	if err != nil {
		return false, 0, 0, err
	}
	count, _ := res[0].(int64)
	ttlMS, _ := res[1].(int64)

	retryAfter = window
	if ttlMS > 0 {
		retryAfter = time.Duration(ttlMS) * time.Millisecond
	}
	remaining = limit - int(count)
	if remaining < 0 {
		remaining = 0
	}
	return count <= int64(limit), remaining, retryAfter, nil
}
