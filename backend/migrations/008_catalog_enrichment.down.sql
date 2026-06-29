DROP TABLE IF EXISTS product_sizes;

DROP INDEX IF EXISTS idx_products_cake_occasion;
DROP INDEX IF EXISTS idx_products_cake_flavor;
DROP INDEX IF EXISTS idx_products_cake_format;
DROP INDEX IF EXISTS idx_products_rating_avg;
DROP INDEX IF EXISTS idx_products_base_price;
DROP INDEX IF EXISTS idx_products_dietary_gin;
DROP INDEX IF EXISTS products_baker_slug_uniq;

ALTER TABLE product_categories DROP COLUMN IF EXISTS icon;
ALTER TABLE product_categories DROP COLUMN IF EXISTS sort_order;
ALTER TABLE product_categories DROP COLUMN IF EXISTS featured;

ALTER TABLE products DROP COLUMN IF EXISTS slug;
ALTER TABLE products DROP COLUMN IF EXISTS subcategory_slug;
ALTER TABLE products DROP COLUMN IF EXISTS dietary;
ALTER TABLE products DROP COLUMN IF EXISTS is_custom;
ALTER TABLE products DROP COLUMN IF EXISTS is_on_offer;
ALTER TABLE products DROP COLUMN IF EXISTS discount_pct;
ALTER TABLE products DROP COLUMN IF EXISTS rating_avg;
ALTER TABLE products DROP COLUMN IF EXISTS rating_count;
ALTER TABLE products DROP COLUMN IF EXISTS cake_occasion;
ALTER TABLE products DROP COLUMN IF EXISTS cake_flavor;
ALTER TABLE products DROP COLUMN IF EXISTS cake_format;
