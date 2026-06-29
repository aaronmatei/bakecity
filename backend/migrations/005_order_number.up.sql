-- Human-friendly sequential order numbers. The UUID `id` remains the internal
-- primary key (referenced by specs, quotes, payments, etc.); order_number is
-- purely for display, e.g. "Order #1042".

CREATE SEQUENCE IF NOT EXISTS order_number_seq START 1001;

ALTER TABLE orders ADD COLUMN IF NOT EXISTS order_number BIGINT;

-- Backfill existing rows in creation order (oldest gets the lowest number).
WITH ordered AS (
    SELECT id, (row_number() OVER (ORDER BY created_at, id) + 1000) AS n
    FROM orders
    WHERE order_number IS NULL
)
UPDATE orders o SET order_number = ordered.n
FROM ordered WHERE ordered.id = o.id;

-- Advance the sequence past the highest backfilled value.
SELECT setval('order_number_seq',
    GREATEST((SELECT COALESCE(MAX(order_number), 1000) FROM orders), 1000));

ALTER TABLE orders ALTER COLUMN order_number SET DEFAULT nextval('order_number_seq');
ALTER TABLE orders ALTER COLUMN order_number SET NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS idx_orders_order_number ON orders(order_number);
