package favorites

import (
	"context"
	"regexp"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// uuidRe loosely validates a UUID so a malformed product id is a no-op rather
// than a 500 from an invalid-uuid cast.
var uuidRe = regexp.MustCompile(`^[0-9a-fA-F-]{36}$`)

// Repository persists customer wishlists (favorited products).
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// ListProductIDs returns the product ids a user has favorited, newest first.
func (r *Repository) ListProductIDs(ctx context.Context, userID string) ([]string, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rows, err := r.db.Query(ctx,
		`SELECT product_id::text FROM favorites WHERE user_id = $1 ORDER BY created_at DESC`,
		userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]string, 0)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// Add favorites a product (idempotent). A non-existent product is ignored.
func (r *Repository) Add(ctx context.Context, userID, productID string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	if !uuidRe.MatchString(productID) {
		return nil
	}
	_, err := r.db.Exec(ctx,
		`INSERT INTO favorites (user_id, product_id)
		 SELECT $1, $2 WHERE EXISTS (SELECT 1 FROM products WHERE id = $2)
		 ON CONFLICT DO NOTHING`,
		userID, productID)
	return err
}

// Remove un-favorites a product (idempotent).
func (r *Repository) Remove(ctx context.Context, userID, productID string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	if !uuidRe.MatchString(productID) {
		return nil
	}
	_, err := r.db.Exec(ctx,
		`DELETE FROM favorites WHERE user_id = $1 AND product_id = $2`,
		userID, productID)
	return err
}

// ListBakerIDs returns the baker_profile ids a user has favorited, newest first.
func (r *Repository) ListBakerIDs(ctx context.Context, userID string) ([]string, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rows, err := r.db.Query(ctx,
		`SELECT baker_id::text FROM favorite_bakers WHERE user_id = $1 ORDER BY created_at DESC`,
		userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]string, 0)
	for rows.Next() {
		var id string
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		out = append(out, id)
	}
	return out, rows.Err()
}

// AddBaker favorites a bakery (idempotent). A non-existent baker is ignored.
func (r *Repository) AddBaker(ctx context.Context, userID, bakerID string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	if !uuidRe.MatchString(bakerID) {
		return nil
	}
	_, err := r.db.Exec(ctx,
		`INSERT INTO favorite_bakers (user_id, baker_id)
		 SELECT $1, $2 WHERE EXISTS (SELECT 1 FROM baker_profiles WHERE id = $2)
		 ON CONFLICT DO NOTHING`,
		userID, bakerID)
	return err
}

// RemoveBaker un-favorites a bakery (idempotent).
func (r *Repository) RemoveBaker(ctx context.Context, userID, bakerID string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	if !uuidRe.MatchString(bakerID) {
		return nil
	}
	_, err := r.db.Exec(ctx,
		`DELETE FROM favorite_bakers WHERE user_id = $1 AND baker_id = $2`,
		userID, bakerID)
	return err
}
