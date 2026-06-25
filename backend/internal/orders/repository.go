package orders

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists orders.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// Create inserts a new order in DRAFT status and returns its id.
func (r *Repository) Create(ctx context.Context, o *Order) (string, error) {
	if r.db == nil {
		return "", pkg.ErrNotImplemented
	}
	var id string
	err := r.db.QueryRow(ctx,
		`INSERT INTO orders
		    (customer_id, baker_id, product_id, status, event_date, delivery_address, total_amount, deposit_amount, balance_amount, commission_amount)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
		 RETURNING id`,
		o.CustomerID, o.BakerID, o.ProductID, o.Status, o.EventDate, o.DeliveryAddress,
		o.TotalAmount, o.DepositAmount, o.BalanceAmount, o.CommissionAmount,
	).Scan(&id)
	return id, err
}

// GetByID fetches a single order.
func (r *Repository) GetByID(ctx context.Context, id string) (*Order, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	var o Order
	err := r.db.QueryRow(ctx,
		`SELECT id, customer_id, baker_id, product_id, status, event_date, delivery_address,
		        total_amount, deposit_amount, balance_amount, commission_amount, created_at
		   FROM orders WHERE id = $1`,
		id,
	).Scan(&o.ID, &o.CustomerID, &o.BakerID, &o.ProductID, &o.Status, &o.EventDate, &o.DeliveryAddress,
		&o.TotalAmount, &o.DepositAmount, &o.BalanceAmount, &o.CommissionAmount, &o.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &o, nil
}

// UpdateStatus transitions an order to a new status.
func (r *Repository) UpdateStatus(ctx context.Context, id, status string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	_, err := r.db.Exec(ctx, `UPDATE orders SET status = $2 WHERE id = $1`, id, status)
	return err
}
