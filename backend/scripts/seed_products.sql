-- Seed a catalogue of products for every approved baker.
--
-- Idempotent: a product is only inserted when the same baker doesn't already
-- have one with that title, so re-running won't create duplicates.
--
-- Run with:
--   docker exec -i bakecity-postgres-1 psql -U bakecity -d bakecity < backend/scripts/seed_products.sql

WITH cat AS (
    SELECT slug, id FROM product_categories
),
tmpl(title, description, base_price, lead_time_days, cat_slug) AS (
    VALUES
        ('Classic Vanilla Cake',     'Moist vanilla sponge with vanilla buttercream',        2500.00, 1, 'cakes'),
        ('Chocolate Fudge Cake',     'Rich chocolate layers with dark chocolate ganache',    3000.00, 2, 'cakes'),
        ('Red Velvet Cake',          'Classic red velvet with cream-cheese frosting',        3200.00, 2, 'cakes'),
        ('Sourdough Loaf',           'Naturally leavened artisan sourdough, baked daily',     600.00, 1, 'bread'),
        ('Whole Wheat Bread',        'Hearty whole-wheat sandwich loaf',                      450.00, 1, 'bread'),
        ('Three-Tier Wedding Cake',  'Elegant three-tier cake with custom flavours & decor', 25000.00, 7, 'wedding-cakes')
)
INSERT INTO products (baker_id, category_id, title, description, base_price, lead_time_days, active)
SELECT b.id, c.id, t.title, t.description, t.base_price, t.lead_time_days, TRUE
FROM baker_profiles b
CROSS JOIN tmpl t
LEFT JOIN cat c ON c.slug = t.cat_slug
WHERE b.status = 'approved'
  AND NOT EXISTS (
      SELECT 1 FROM products p
      WHERE p.baker_id = b.id AND p.title = t.title
  );

-- Summary
SELECT b.business_name, count(p.id) AS product_count
FROM baker_profiles b
LEFT JOIN products p ON p.baker_id = b.id
WHERE b.status = 'approved'
GROUP BY b.business_name
ORDER BY b.business_name;
