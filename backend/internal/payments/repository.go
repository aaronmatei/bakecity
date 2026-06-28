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

const payoutColumns = `id, baker_id, amount, COALESCE(psp_ref, ''), status, created_at`

func scanPayout(row pgx.Row) (*Payout, error) {
	var p Payout
	err := row.Scan(&p.ID, &p.BakerID, &p.Amount, &p.PSPRef, &p.Status, &p.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &p, nil
}

// CreatePayout inserts a pending payout for a baker.
func (r *Repository) CreatePayout(ctx context.Context, bakerID string, amount float64) (*Payout, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanPayout(r.db.QueryRow(ctx,
		`INSERT INTO payouts (baker_id, amount, status) VALUES ($1, $2, $3)
		 RETURNING `+payoutColumns,
		bakerID, amount, PayoutPending,
	))
}

// UpdatePayoutStatus sets a payout's status and (on success) its PSP reference.
func (r *Repository) UpdatePayoutStatus(ctx context.Context, id, status, pspRef string) (*Payout, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanPayout(r.db.QueryRow(ctx,
		`UPDATE payouts SET status = $2, psp_ref = COALESCE(NULLIF($3, ''), psp_ref)
		  WHERE id = $1 RETURNING `+payoutColumns,
		id, status, pspRef,
	))
}

// BakerPhone returns the phone of the user who owns a baker profile, or
// ErrNotFound if the baker does not exist.
func (r *Repository) BakerPhone(ctx context.Context, bakerID string) (string, error) {
	if r.db == nil {
		return "", pkg.ErrNotImplemented
	}
	var phone string
	err := r.db.QueryRow(ctx,
		`SELECT u.phone FROM baker_profiles b JOIN users u ON u.id = b.user_id WHERE b.id = $1`,
		bakerID,
	).Scan(&phone)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", pkg.ErrNotFound
	}
	return phone, err
}
