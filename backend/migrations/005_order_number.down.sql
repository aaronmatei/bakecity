DROP INDEX IF EXISTS idx_orders_order_number;
ALTER TABLE orders DROP COLUMN IF EXISTS order_number;
DROP SEQUENCE IF EXISTS order_number_seq;
