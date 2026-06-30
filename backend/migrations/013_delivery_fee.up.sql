-- Migration: 013_delivery_fee.up.sql
-- Adds customer-chosen fulfillment (pickup vs delivery) and a courier/delivery
-- fee. The fee is set by the baker on a quote and, for delivery orders, added to
-- the order total (into the balance) — it is pass-through and not commissioned.

ALTER TABLE orders ADD COLUMN IF NOT EXISTS fulfillment_type VARCHAR(20) NOT NULL DEFAULT 'delivery';
ALTER TABLE orders ADD COLUMN IF NOT EXISTS delivery_fee NUMERIC(12,2) NOT NULL DEFAULT 0;
ALTER TABLE quotes ADD COLUMN IF NOT EXISTS delivery_fee NUMERIC(12,2) NOT NULL DEFAULT 0;
