-- Migration: 003_delivery_unique_order.down.sql

ALTER TABLE deliveries
    DROP CONSTRAINT IF EXISTS deliveries_order_id_key;

CREATE INDEX IF NOT EXISTS idx_deliveries_order_id ON deliveries(order_id);
