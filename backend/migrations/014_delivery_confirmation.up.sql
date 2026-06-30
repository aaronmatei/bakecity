-- Migration: 014_delivery_confirmation.up.sql
-- Stricter delivery: the baker submits proof (recording proof_submitted_at) but
-- the order only becomes DELIVERED when the customer confirms receipt — or when
-- a background sweep auto-confirms after a fallback window.

ALTER TABLE deliveries ADD COLUMN IF NOT EXISTS proof_submitted_at TIMESTAMPTZ;
