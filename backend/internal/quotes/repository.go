package quotes

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists quotes domain data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const quoteColumns = `id, order_id, version, amount, deposit_pct, valid_until, status, proposed_by, is_final, created_at`

func scanQuote(row pgx.Row) (*Quote, error) {
	var q Quote
	err := row.Scan(&q.ID, &q.OrderID, &q.Version, &q.Amount, &q.DepositPct,
		&q.ValidUntil, &q.Status, &q.ProposedBy, &q.IsFinal, &q.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &q, nil
}

// Create supersedes any pending quotes for the order, then inserts a new quote
// at the next version, atomically. proposedBy is "baker" or "customer".
func (r *Repository) Create(ctx context.Context, orderID string, amount, depositPct float64, validUntil *time.Time, proposedBy string, isFinal bool) (*Quote, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx) //nolint:errcheck // no-op once committed

	// Only the newest offer/quote stays live, so a counter supersedes the
	// other party's pending one.
	if _, err := tx.Exec(ctx,
		`UPDATE quotes SET status = $2 WHERE order_id = $1 AND status = $3`,
		orderID, StatusSuperseded, StatusPending,
	); err != nil {
		return nil, err
	}

	q, err := scanQuote(tx.QueryRow(ctx,
		`INSERT INTO quotes (order_id, version, amount, deposit_pct, valid_until, status, proposed_by, is_final)
		 VALUES ($1, (SELECT COALESCE(MAX(version), 0) + 1 FROM quotes WHERE order_id = $1), $2, $3, $4, $5, $6, $7)
		 RETURNING `+quoteColumns,
		orderID, amount, depositPct, validUntil, StatusPending, proposedBy, isFinal,
	))
	if err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return q, nil
}

// GetByID fetches a single quote.
func (r *Repository) GetByID(ctx context.Context, id string) (*Quote, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanQuote(r.db.QueryRow(ctx, `SELECT `+quoteColumns+` FROM quotes WHERE id = $1`, id))
}

// ListByOrder returns an order's quotes, newest version first.
func (r *Repository) ListByOrder(ctx context.Context, orderID string) ([]Quote, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rows, err := r.db.Query(ctx,
		`SELECT `+quoteColumns+` FROM quotes WHERE order_id = $1 ORDER BY version DESC`, orderID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Quote, 0)
	for rows.Next() {
		var q Quote
		if err := rows.Scan(&q.ID, &q.OrderID, &q.Version, &q.Amount, &q.DepositPct,
			&q.ValidUntil, &q.Status, &q.ProposedBy, &q.IsFinal, &q.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, q)
	}
	return out, rows.Err()
}

// SetStatus updates a quote's status.
func (r *Repository) SetStatus(ctx context.Context, id, status string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	_, err := r.db.Exec(ctx, `UPDATE quotes SET status = $2 WHERE id = $1`, id, status)
	return err
}
