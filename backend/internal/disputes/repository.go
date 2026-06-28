package disputes

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists disputes domain data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const disputeColumns = `id, order_id, raised_by, reason, status,
	COALESCE(resolution, ''), COALESCE(refund_amount, 0),
	COALESCE(resolved_by::text, ''), resolved_at, created_at`

func scanDispute(row pgx.Row) (*Dispute, error) {
	var d Dispute
	err := row.Scan(&d.ID, &d.OrderID, &d.RaisedBy, &d.Reason, &d.Status,
		&d.Resolution, &d.RefundAmount, &d.ResolvedBy, &d.ResolvedAt, &d.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &d, nil
}

// Create inserts an open dispute for an order.
func (r *Repository) Create(ctx context.Context, orderID, raisedBy, reason string) (*Dispute, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanDispute(r.db.QueryRow(ctx,
		`INSERT INTO disputes (order_id, raised_by, reason, status)
		 VALUES ($1, $2, $3, $4)
		 RETURNING `+disputeColumns,
		orderID, raisedBy, reason, StatusOpen,
	))
}

// GetByID fetches a single dispute.
func (r *Repository) GetByID(ctx context.Context, id string) (*Dispute, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanDispute(r.db.QueryRow(ctx, `SELECT `+disputeColumns+` FROM disputes WHERE id = $1`, id))
}

// ListByOrder returns an order's disputes, newest first.
func (r *Repository) ListByOrder(ctx context.Context, orderID string) ([]Dispute, error) {
	return r.list(ctx, `WHERE order_id = $1 ORDER BY created_at DESC`, orderID)
}

// ListByStatus returns disputes with the given status (oldest first, so the
// admin queue is FIFO), paged.
func (r *Repository) ListByStatus(ctx context.Context, status string, limit, offset int) ([]Dispute, error) {
	return r.list(ctx, `WHERE status = $1 ORDER BY created_at ASC LIMIT $2 OFFSET $3`, status, limit, offset)
}

func (r *Repository) list(ctx context.Context, where string, args ...any) ([]Dispute, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rows, err := r.db.Query(ctx, `SELECT `+disputeColumns+` FROM disputes `+where, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Dispute, 0)
	for rows.Next() {
		var d Dispute
		if err := rows.Scan(&d.ID, &d.OrderID, &d.RaisedBy, &d.Reason, &d.Status,
			&d.Resolution, &d.RefundAmount, &d.ResolvedBy, &d.ResolvedAt, &d.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, d)
	}
	return out, rows.Err()
}

// Resolve records an admin ruling on an open dispute. Returns ErrNotFound if no
// open dispute with that id exists (already resolved or missing).
func (r *Repository) Resolve(ctx context.Context, id, status, resolution string, refundAmount float64, resolvedBy string, resolvedAt time.Time) (*Dispute, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanDispute(r.db.QueryRow(ctx,
		`UPDATE disputes
		    SET status = $2, resolution = $3, refund_amount = $4,
		        resolved_by = $5, resolved_at = $6
		  WHERE id = $1 AND status = $7
		 RETURNING `+disputeColumns,
		id, status, resolution, refundAmount, resolvedBy, resolvedAt, StatusOpen,
	))
}
