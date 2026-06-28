-- Migration: 004_device_tokens.up.sql
-- Stores per-device push tokens (FCM) so push notifications can be fanned out
-- to a user's registered devices. The token is the primary key, so a device
-- re-registering simply upserts (and can be reassigned to a new user after a
-- reinstall/login).

CREATE TABLE IF NOT EXISTS device_tokens (
    token      TEXT PRIMARY KEY,
    user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform   VARCHAR(16) NOT NULL DEFAULT 'unknown',
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON device_tokens(user_id);
