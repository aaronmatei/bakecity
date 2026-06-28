-- Migration: 003_delivery_unique_order.up.sql
-- Phase 6: one delivery per order. Replaces the plain index with a UNIQUE
-- constraint so dispatch can upsert the order's delivery row idempotently.

DROP INDEX IF EXISTS idx_deliveries_order_id;

ALTER TABLE deliveries
    ADD CONSTRAINT deliveries_order_id_key UNIQUE (order_id);
