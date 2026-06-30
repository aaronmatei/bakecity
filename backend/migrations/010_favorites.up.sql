-- Migration: 010_favorites.up.sql
-- Persists a customer's favorited products (wishlist) so they sync across
-- devices instead of living only in on-device storage.

CREATE TABLE IF NOT EXISTS favorites (
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, product_id)
);

CREATE INDEX IF NOT EXISTS idx_favorites_user ON favorites(user_id, created_at DESC);
