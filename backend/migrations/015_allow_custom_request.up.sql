-- Migration: 015_allow_custom_request.up.sql
-- Lets a fixed (sold-as-is) product optionally offer a "request a custom version"
-- path that drops into the quote flow.

ALTER TABLE products ADD COLUMN IF NOT EXISTS allow_custom_request BOOLEAN NOT NULL DEFAULT false;
