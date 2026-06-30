-- Migration: 014_delivery_confirmation.down.sql
ALTER TABLE deliveries DROP COLUMN IF EXISTS proof_submitted_at;
