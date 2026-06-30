package reviews

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists reviews domain data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const reviewColumns = `id, order_id, customer_id, baker_id, rating, COALESCE(body, ''), created_at`

func scanReview(row pgx.Row) (*Review, error) {
	var r Review
	err := row.Scan(&r.ID, &r.OrderID, &r.CustomerID, &r.BakerID, &r.Rating, &r.Body, &r.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &r, nil
}

// Create inserts a review. A duplicate (order_id, customer_id) yields
// ErrConflict (the order was already reviewed).
func (r *Repository) Create(ctx context.Context, orderID, customerID, bakerID string, rating int, body string) (*Review, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rev, err := scanReview(r.db.QueryRow(ctx,
		`INSERT INTO reviews (order_id, customer_id, baker_id, rating, body)
		 VALUES ($1, $2, $3, $4, NULLIF($5, ''))
		 RETURNING `+reviewColumns,
		orderID, customerID, bakerID, rating, body,
	))
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" { // unique_violation
		return nil, pkg.ErrConflict
	}
	if err != nil {
		return nil, err
	}
	return rev, nil
}

// GetByOrder returns an order's review, or ErrNotFound if none exists.
func (r *Repository) GetByOrder(ctx context.Context, orderID string) (*Review, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanReview(r.db.QueryRow(ctx, `SELECT `+reviewColumns+` FROM reviews WHERE order_id = $1`, orderID))
}

// ListByBaker returns a baker's reviews (newest first) plus the aggregate
// average rating and count.
func (r *Repository) ListByBaker(ctx context.Context, bakerID string, limit, offset int) (*BakerReviews, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	out := &BakerReviews{BakerID: bakerID, Reviews: make([]Review, 0)}
	if err := r.db.QueryRow(ctx,
		`SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 0), COUNT(*) FROM reviews WHERE baker_id = $1`,
		bakerID,
	).Scan(&out.AverageRating, &out.Count); err != nil {
		return nil, err
	}

	// Per-star distribution over all of the baker's reviews.
	distRows, err := r.db.Query(ctx,
		`SELECT rating, COUNT(*) FROM reviews WHERE baker_id = $1 GROUP BY rating`, bakerID)
	if err != nil {
		return nil, err
	}
	defer distRows.Close()
	for distRows.Next() {
		var star, n int
		if err := distRows.Scan(&star, &n); err != nil {
			return nil, err
		}
		if star >= 1 && star <= 5 {
			out.Distribution[star-1] = n
		}
	}
	if err := distRows.Err(); err != nil {
		return nil, err
	}

	rows, err := r.db.Query(ctx,
		`SELECT r.id, r.order_id, r.customer_id, r.baker_id, r.rating,
		        COALESCE(r.body, ''), r.created_at, COALESCE(u.name, '')
		   FROM reviews r LEFT JOIN users u ON u.id = r.customer_id
		  WHERE r.baker_id = $1
		  ORDER BY r.created_at DESC, r.id DESC LIMIT $2 OFFSET $3`,
		bakerID, limit, offset,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	for rows.Next() {
		var rev Review
		if err := rows.Scan(&rev.ID, &rev.OrderID, &rev.CustomerID, &rev.BakerID,
			&rev.Rating, &rev.Body, &rev.CreatedAt, &rev.CustomerName); err != nil {
			return nil, err
		}
		out.Reviews = append(out.Reviews, rev)
	}
	return out, rows.Err()
}
