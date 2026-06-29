-- Attach a product photo to each seeded product (by title).
--
-- Each image is stored as a media row (media.s3_key holds the full external URL)
-- linked to the product via product_images. Idempotent: products that already
-- have an image are skipped, so re-running is safe.
--
-- Run with:
--   docker exec -i bakecity-postgres-1 psql -U bakecity -d bakecity < backend/scripts/seed_product_images.sql

DO $$
DECLARE
    r   RECORD;
    mid UUID;
BEGIN
    FOR r IN
        SELECT p.id AS product_id, b.user_id, i.url
        FROM products p
        JOIN baker_profiles b ON b.id = p.baker_id
        JOIN (VALUES
            ('Classic Vanilla Cake',     'https://images.unsplash.com/photo-1535141192574-5d4897c12636?w=800&q=80'),
            ('Chocolate Fudge Cake',     'https://images.unsplash.com/photo-1606890737304-57a1ca8a5b62?w=800&q=80'),
            ('Red Velvet Cake',          'https://images.unsplash.com/photo-1586788680434-30d324b2d46f?w=800&q=80'),
            ('Sourdough Loaf',           'https://images.unsplash.com/photo-1509440159596-0249088772ff?w=800&q=80'),
            ('Whole Wheat Bread',        'https://images.unsplash.com/photo-1598373182133-52452f7691ef?w=800&q=80'),
            ('Three-Tier Wedding Cake',  'https://images.unsplash.com/photo-1623428187969-5da2dcea5ebf?w=800&q=80')
        ) AS i(title, url) ON i.title = p.title
        WHERE NOT EXISTS (
            SELECT 1 FROM product_images pi WHERE pi.product_id = p.id
        )
    LOOP
        INSERT INTO media (owner_id, kind, s3_key, status)
        VALUES (r.user_id, 'product', r.url, 'ready')
        RETURNING id INTO mid;

        INSERT INTO product_images (product_id, media_id, position)
        VALUES (r.product_id, mid, 0);
    END LOOP;
END $$;

-- Summary
SELECT count(*) AS products_with_images
FROM products p
WHERE EXISTS (SELECT 1 FROM product_images pi WHERE pi.product_id = p.id);
