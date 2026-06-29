-- Catalog enrichment: multi-axis filtering on products, cake attributes,
-- weight-based sizes, denormalized ratings, and category presentation.

-- Products: filtering axes + denormalized rating + a stable slug for idempotent
-- seeding (unique per baker).
ALTER TABLE products ADD COLUMN IF NOT EXISTS slug             VARCHAR(255);
ALTER TABLE products ADD COLUMN IF NOT EXISTS subcategory_slug VARCHAR(120);
ALTER TABLE products ADD COLUMN IF NOT EXISTS dietary          TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_custom        BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_on_offer      BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE products ADD COLUMN IF NOT EXISTS discount_pct     INTEGER;
ALTER TABLE products ADD COLUMN IF NOT EXISTS rating_avg       NUMERIC(3,2) NOT NULL DEFAULT 0;
ALTER TABLE products ADD COLUMN IF NOT EXISTS rating_count     INTEGER NOT NULL DEFAULT 0;

-- Cake-specific attributes (nullable for non-cakes).
ALTER TABLE products ADD COLUMN IF NOT EXISTS cake_occasion    VARCHAR(40);
ALTER TABLE products ADD COLUMN IF NOT EXISTS cake_flavor      VARCHAR(40);
ALTER TABLE products ADD COLUMN IF NOT EXISTS cake_format      VARCHAR(40);

-- One product per (baker, slug); seeded rows carry a slug, legacy rows keep NULL
-- (Postgres treats NULLs as distinct, so they don't collide).
CREATE UNIQUE INDEX IF NOT EXISTS products_baker_slug_uniq ON products (baker_id, slug);

-- Category presentation.
ALTER TABLE product_categories ADD COLUMN IF NOT EXISTS icon       VARCHAR(80);
ALTER TABLE product_categories ADD COLUMN IF NOT EXISTS sort_order INTEGER NOT NULL DEFAULT 0;
ALTER TABLE product_categories ADD COLUMN IF NOT EXISTS featured   BOOLEAN NOT NULL DEFAULT false;

-- Weight-based pricing (cakes are sold by weight in KE).
CREATE TABLE IF NOT EXISTS product_sizes (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    label      VARCHAR(40) NOT NULL,
    weight_kg  NUMERIC(5,2),
    serves     INTEGER,
    price      NUMERIC(12,2) NOT NULL,
    UNIQUE (product_id, label)
);

-- Filter-supporting indexes.
CREATE INDEX IF NOT EXISTS idx_products_cake_occasion ON products (cake_occasion);
CREATE INDEX IF NOT EXISTS idx_products_cake_flavor   ON products (cake_flavor);
CREATE INDEX IF NOT EXISTS idx_products_cake_format   ON products (cake_format);
CREATE INDEX IF NOT EXISTS idx_products_rating_avg    ON products (rating_avg);
CREATE INDEX IF NOT EXISTS idx_products_base_price    ON products (base_price);
CREATE INDEX IF NOT EXISTS idx_products_dietary_gin   ON products USING GIN (dietary);
CREATE INDEX IF NOT EXISTS idx_product_sizes_product  ON product_sizes (product_id);
