package production

import (
	"context"
	"errors"
	"net/http"

	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists production domain data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const updateColumns = `id, order_id, stage, progress_pct, COALESCE(notes, ''),
	COALESCE(media_id::text, ''), created_at`

// Insert records a production update for an order. A non-empty mediaID that does
// not exist yields a 422 APIError.
func (r *Repository) Insert(ctx context.Context, orderID, stage string, progressPct int, notes, mediaID string) (*Update, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	var u Update
	err := r.db.QueryRow(ctx,
		`INSERT INTO production_updates (order_id, stage, progress_pct, notes, media_id)
		 VALUES ($1, $2, $3, NULLIF($4, ''), NULLIF($5, '')::uuid)
		 RETURNING `+updateColumns,
		orderID, stage, progressPct, notes, mediaID,
	).Scan(&u.ID, &u.OrderID, &u.Stage, &u.ProgressPct, &u.Notes, &u.MediaID, &u.CreatedAt)
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23503" { // foreign_key_violation (media_id)
		return nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation, "media_id does not exist")
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// ListByOrder returns an order's production updates in chronological order.
func (r *Repository) ListByOrder(ctx context.Context, orderID string) ([]Update, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rows, err := r.db.Query(ctx,
		`SELECT `+updateColumns+` FROM production_updates WHERE order_id = $1
		  ORDER BY created_at ASC, id ASC`,
		orderID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Update, 0)
	for rows.Next() {
		var u Update
		if err := rows.Scan(&u.ID, &u.OrderID, &u.Stage, &u.ProgressPct, &u.Notes,
			&u.MediaID, &u.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, u)
	}
	return out, rows.Err()
}
