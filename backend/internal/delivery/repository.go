package delivery

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists delivery domain data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const deliveryColumns = `id, order_id, method, COALESCE(courier_ref, ''), status,
	COALESCE(proof_media_id::text, ''), dispatched_at, proof_submitted_at,
	delivered_at, confirmed_at, created_at`

func scanDelivery(row pgx.Row) (*Delivery, error) {
	var d Delivery
	err := row.Scan(&d.ID, &d.OrderID, &d.Method, &d.CourierRef, &d.Status,
		&d.ProofMediaID, &d.DispatchedAt, &d.ProofSubmittedAt, &d.DeliveredAt, &d.ConfirmedAt, &d.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &d, nil
}

// GetByOrder returns an order's delivery, or ErrNotFound if none exists yet.
func (r *Repository) GetByOrder(ctx context.Context, orderID string) (*Delivery, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanDelivery(r.db.QueryRow(ctx,
		`SELECT `+deliveryColumns+` FROM deliveries WHERE order_id = $1`, orderID))
}

// Dispatch creates (or re-dispatches) the order's delivery row, stamping
// dispatched_at. One delivery per order via UNIQUE(order_id) upsert.
func (r *Repository) Dispatch(ctx context.Context, orderID, method, courierRef string) (*Delivery, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanDelivery(r.db.QueryRow(ctx,
		`INSERT INTO deliveries (order_id, method, courier_ref, status, dispatched_at)
		 VALUES ($1, $2, NULLIF($3, ''), $4, now())
		 ON CONFLICT (order_id) DO UPDATE
		    SET method = EXCLUDED.method, courier_ref = EXCLUDED.courier_ref,
		        status = EXCLUDED.status, dispatched_at = now()
		 RETURNING `+deliveryColumns,
		orderID, method, courierRef, StatusDispatched,
	))
}

// SubmitProof records the baker's proof-of-delivery on a dispatched delivery and
// stamps proof_submitted_at (once), without confirming receipt. A non-empty
// proofMediaID that does not exist yields a 422 APIError.
func (r *Repository) SubmitProof(ctx context.Context, orderID, proofMediaID string) (*Delivery, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	d, err := scanDelivery(r.db.QueryRow(ctx,
		`UPDATE deliveries
		    SET proof_media_id = COALESCE(NULLIF($2, '')::uuid, proof_media_id),
		        proof_submitted_at = COALESCE(proof_submitted_at, now())
		  WHERE order_id = $1
		 RETURNING `+deliveryColumns,
		orderID, proofMediaID,
	))
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23503" { // foreign_key_violation
		return nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation, "proof_media_id does not exist")
	}
	return d, err
}

// ListStaleAwaitingConfirmation returns order ids whose baker submitted proof
// before cutoff but the order is still dispatched (customer hasn't confirmed) —
// candidates for auto-confirmation.
func (r *Repository) ListStaleAwaitingConfirmation(ctx context.Context, cutoff time.Time) ([]string, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rows, err := r.db.Query(ctx,
		`SELECT order_id::text FROM deliveries
		  WHERE status = $1 AND proof_submitted_at IS NOT NULL AND proof_submitted_at < $2`,
		StatusDispatched, cutoff)
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

// Confirm marks the order's delivery delivered, recording proof-of-delivery and
// stamping delivered_at/confirmed_at. A non-empty proofMediaID that does not
// exist yields a 422 APIError.
func (r *Repository) Confirm(ctx context.Context, orderID, proofMediaID string) (*Delivery, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	d, err := scanDelivery(r.db.QueryRow(ctx,
		`UPDATE deliveries
		    SET status = $2,
		        proof_media_id = COALESCE(NULLIF($3, '')::uuid, proof_media_id),
		        delivered_at = COALESCE(delivered_at, now()),
		        confirmed_at = now()
		  WHERE order_id = $1
		 RETURNING `+deliveryColumns,
		orderID, StatusDelivered, proofMediaID,
	))
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23503" { // foreign_key_violation (proof_media_id)
		return nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation, "proof_media_id does not exist")
	}
	return d, err
}
