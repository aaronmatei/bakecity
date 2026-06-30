-- Migration: 013_delivery_fee.down.sql
ALTER TABLE orders DROP COLUMN IF EXISTS fulfillment_type;
ALTER TABLE orders DROP COLUMN IF EXISTS delivery_fee;
ALTER TABLE quotes DROP COLUMN IF EXISTS delivery_fee;
