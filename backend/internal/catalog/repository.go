package catalog

import (
	"context"
	"errors"
	"fmt"
	"strconv"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists catalog domain data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// ---- Categories ----

// ListCategories returns all categories, alphabetically.
func (r *Repository) ListCategories(ctx context.Context) ([]Category, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rows, err := r.db.Query(ctx, `SELECT id, name, slug FROM product_categories ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Category, 0)
	for rows.Next() {
		var cat Category
		if err := rows.Scan(&cat.ID, &cat.Name, &cat.Slug); err != nil {
			return nil, err
		}
		out = append(out, cat)
	}
	return out, rows.Err()
}

// CreateCategory inserts a category, returning ErrConflict on a duplicate slug.
func (r *Repository) CreateCategory(ctx context.Context, name, slug string) (*Category, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	var cat Category
	err := r.db.QueryRow(ctx,
		`INSERT INTO product_categories (name, slug) VALUES ($1, $2) RETURNING id, name, slug`,
		name, slug,
	).Scan(&cat.ID, &cat.Name, &cat.Slug)
	if isUniqueViolation(err) {
		return nil, pkg.ErrConflict
	}
	if err != nil {
		return nil, err
	}
	return &cat, nil
}

// ---- Products ----

const productColumns = `id, baker_id, COALESCE(category_id::text, ''), title,
	COALESCE(description, ''), base_price, lead_time_days, active, created_at, updated_at`

// imageURLsExpr aggregates a product's image URLs (media.s3_key holds a full URL
// for seeded/external images) ordered by position. Leading comma so it appends
// to productColumns in SELECT queries.
const imageURLsExpr = `, COALESCE(ARRAY(
	SELECT m.s3_key FROM product_images pim
	JOIN media m ON m.id = pim.media_id
	WHERE pim.product_id = products.id
	ORDER BY pim.position
), '{}'::text[])`

func scanProduct(row pgx.Row) (*Product, error) {
	var p Product
	err := row.Scan(&p.ID, &p.BakerID, &p.CategoryID, &p.Title, &p.Description,
		&p.BasePrice, &p.LeadTimeDays, &p.Active, &p.CreatedAt, &p.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

// BakerIDForUser resolves the baker_profiles.id owned by userID, or ErrNotFound.
func (r *Repository) BakerIDForUser(ctx context.Context, userID string) (string, error) {
	if r.db == nil {
		return "", pkg.ErrNotImplemented
	}
	var id string
	err := r.db.QueryRow(ctx, `SELECT id FROM baker_profiles WHERE user_id = $1`, userID).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", pkg.ErrNotFound
	}
	return id, err
}

// CreateProduct inserts a product owned by bakerID.
func (r *Repository) CreateProduct(ctx context.Context, bakerID string, req CreateProductRequest) (*Product, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanProduct(r.db.QueryRow(ctx,
		`INSERT INTO products (baker_id, category_id, title, description, base_price, lead_time_days)
		 VALUES ($1, NULLIF($2, '')::uuid, $3, NULLIF($4, ''), $5, COALESCE($6, 1))
		 RETURNING `+productColumns,
		bakerID, req.CategoryID, req.Title, req.Description, req.BasePrice, req.LeadTimeDays,
	))
}

// GetProduct fetches a single product, including its image URLs.
func (r *Repository) GetProduct(ctx context.Context, id string) (*Product, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	var p Product
	err := r.db.QueryRow(ctx, `SELECT `+productColumns+imageURLsExpr+` FROM products WHERE id = $1`, id).
		Scan(&p.ID, &p.BakerID, &p.CategoryID, &p.Title, &p.Description,
			&p.BasePrice, &p.LeadTimeDays, &p.Active, &p.CreatedAt, &p.UpdatedAt, &p.ImageURLs)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	sizes, err := r.listSizes(ctx, p.ID)
	if err != nil {
		return nil, err
	}
	p.Sizes = sizes
	return &p, nil
}

// listSizes returns a product's weight/serving options, cheapest first.
func (r *Repository) listSizes(ctx context.Context, productID string) ([]ProductSize, error) {
	rows, err := r.db.Query(ctx,
		`SELECT id, label, weight_kg, serves, price FROM product_sizes
		   WHERE product_id = $1 ORDER BY price`, productID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := make([]ProductSize, 0)
	for rows.Next() {
		var s ProductSize
		if err := rows.Scan(&s.ID, &s.Label, &s.WeightKg, &s.Serves, &s.Price); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// ProductOwner returns the (bakerID, ownerUserID) for a product, or ErrNotFound.
func (r *Repository) ProductOwner(ctx context.Context, productID string) (string, string, error) {
	if r.db == nil {
		return "", "", pkg.ErrNotImplemented
	}
	var bakerID, userID string
	err := r.db.QueryRow(ctx,
		`SELECT b.id, b.user_id FROM products p JOIN baker_profiles b ON b.id = p.baker_id WHERE p.id = $1`,
		productID,
	).Scan(&bakerID, &userID)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", "", pkg.ErrNotFound
	}
	return bakerID, userID, err
}

// ListProducts returns products matching filter, newest first.
func (r *Repository) ListProducts(ctx context.Context, f ProductFilter) ([]Product, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	q := `SELECT ` + productColumns + imageURLsExpr + ` FROM products WHERE 1 = 1`
	args := []any{}
	add := func(cond string, val any) {
		args = append(args, val)
		q += fmt.Sprintf(" AND %s $%d", cond, len(args))
	}
	if f.BakerID != "" {
		add("baker_id =", f.BakerID)
	}
	if f.CategoryID != "" {
		add("category_id =", f.CategoryID)
	}
	switch f.Active {
	case "false":
		add("active =", false)
	case "all":
		// no filter
	default:
		add("active =", true)
	}
	args = append(args, f.Limit)
	q += " ORDER BY created_at DESC LIMIT $" + strconv.Itoa(len(args))
	args = append(args, f.Offset)
	q += " OFFSET $" + strconv.Itoa(len(args))

	rows, err := r.db.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Product, 0)
	for rows.Next() {
		var p Product
		if err := rows.Scan(&p.ID, &p.BakerID, &p.CategoryID, &p.Title, &p.Description,
			&p.BasePrice, &p.LeadTimeDays, &p.Active, &p.CreatedAt, &p.UpdatedAt, &p.ImageURLs); err != nil {
			return nil, err
		}
		out = append(out, p)
	}
	return out, rows.Err()
}

// UpdateProduct applies a partial update and returns the result.
func (r *Repository) UpdateProduct(ctx context.Context, id string, req UpdateProductRequest) (*Product, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanProduct(r.db.QueryRow(ctx,
		`UPDATE products SET
		    category_id    = CASE WHEN $2::text IS NULL THEN category_id ELSE NULLIF($2, '')::uuid END,
		    title          = COALESCE($3, title),
		    description    = COALESCE($4, description),
		    base_price     = COALESCE($5, base_price),
		    lead_time_days = COALESCE($6, lead_time_days),
		    active         = COALESCE($7, active),
		    updated_at     = now()
		  WHERE id = $1
		RETURNING `+productColumns,
		id, req.CategoryID, req.Title, req.Description, req.BasePrice, req.LeadTimeDays, req.Active,
	))
}

// isUniqueViolation reports whether err is a Postgres unique-constraint error.
func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
