package pkg

import (
	"context"
	"errors"
	"time"

	"github.com/redis/go-redis/v9"
)

// ErrIdempotencyConflict is returned when a key has already been processed.
var ErrIdempotencyConflict = errors.New("idempotency key already processed")

// IdempotencyStore is a Redis-backed store for idempotency keys. It guards
// payment and webhook endpoints against duplicate processing.
type IdempotencyStore struct {
	rdb *redis.Client
	ttl time.Duration
}

// NewIdempotencyStore constructs a store. A zero ttl defaults to 24h.
func NewIdempotencyStore(rdb *redis.Client, ttl time.Duration) *IdempotencyStore {
	if ttl <= 0 {
		ttl = 24 * time.Hour
	}
	return &IdempotencyStore{rdb: rdb, ttl: ttl}
}

func (s *IdempotencyStore) redisKey(scope, key string) string {
	return "idem:" + scope + ":" + key
}

// Check returns the previously stored result for key (if any) and whether it
// exists. An empty key or nil client always reports a miss.
func (s *IdempotencyStore) Check(ctx context.Context, scope, key string) (result string, found bool, err error) {
	if s == nil || s.rdb == nil || key == "" {
		return "", false, nil
	}
	val, err := s.rdb.Get(ctx, s.redisKey(scope, key)).Result()
	if errors.Is(err, redis.Nil) {
		return "", false, nil
	}
	if err != nil {
		return "", false, err
	}
	return val, true, nil
}

// Save atomically records key with the given result, failing with
// ErrIdempotencyConflict if it already exists.
func (s *IdempotencyStore) Save(ctx context.Context, scope, key, result string) error {
	if s == nil || s.rdb == nil || key == "" {
		return nil
	}
	ok, err := s.rdb.SetNX(ctx, s.redisKey(scope, key), result, s.ttl).Result()
	if err != nil {
		return err
	}
	if !ok {
		return ErrIdempotencyConflict
	}
	return nil
}

// Delete releases a reservation so it can be retried (e.g. after a processing
// failure following a Save).
func (s *IdempotencyStore) Delete(ctx context.Context, scope, key string) error {
	if s == nil || s.rdb == nil || key == "" {
		return nil
	}
	return s.rdb.Del(ctx, s.redisKey(scope, key)).Err()
}
