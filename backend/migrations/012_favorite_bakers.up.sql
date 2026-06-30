-- Migration: 012_favorite_bakers.up.sql
-- Lets a customer follow/favorite bakeries (separate from product favorites).

CREATE TABLE IF NOT EXISTS favorite_bakers (
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    baker_id   UUID NOT NULL REFERENCES baker_profiles(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, baker_id)
);

CREATE INDEX IF NOT EXISTS idx_favorite_bakers_user ON favorite_bakers(user_id, created_at DESC);
