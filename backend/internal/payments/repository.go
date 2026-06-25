package payments

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists payment records.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const paymentColumns = `id, order_id, kind, COALESCE(psp_ref, ''), amount, status,
	COALESCE(idempotency_key, ''), created_at`

func scanPayment(row pgx.Row) (*Payment, error) {
	var p Payment
	err := row.Scan(&p.ID, &p.OrderID, &p.Kind, &p.PSPRef, &p.Amount, &p.Status,
		&p.IdempotencyKey, &p.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

// Create inserts a payment. A duplicate idempotency_key yields ErrConflict.
func (r *Repository) Create(ctx context.Context, p *Payment) (*Payment, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	created, err := scanPayment(r.db.QueryRow(ctx,
		`INSERT INTO payments (order_id, kind, psp_ref, amount, status, idempotency_key)
		 VALUES ($1, $2, NULLIF($3, ''), $4, $5, NULLIF($6, ''))
		 RETURNING `+paymentColumns,
		p.OrderID, p.Kind, p.PSPRef, p.Amount, p.Status, p.IdempotencyKey,
	))
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23505" {
		return nil, pkg.ErrConflict
	}
	return created, err
}

// GetByIdempotencyKey returns a payment by its idempotency key, or ErrNotFound.
func (r *Repository) GetByIdempotencyKey(ctx context.Context, key string) (*Payment, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanPayment(r.db.QueryRow(ctx,
		`SELECT `+paymentColumns+` FROM payments WHERE idempotency_key = $1`, key))
}

// GetByPSPRef returns a payment by its PSP reference, or ErrNotFound.
func (r *Repository) GetByPSPRef(ctx context.Context, ref string) (*Payment, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanPayment(r.db.QueryRow(ctx,
		`SELECT `+paymentColumns+` FROM payments WHERE psp_ref = $1`, ref))
}

// UpdateStatus sets a payment's status.
func (r *Repository) UpdateStatus(ctx context.Context, id, status string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	_, err := r.db.Exec(ctx, `UPDATE payments SET status = $2 WHERE id = $1`, id, status)
	return err
}
