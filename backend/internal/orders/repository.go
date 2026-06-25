package orders

import (
	"context"
	"errors"
	"strconv"
	"time"

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

const orderColumns = `id, customer_id, baker_id, COALESCE(product_id::text, ''), status,
	event_date, COALESCE(delivery_address, ''),
	total_amount, deposit_amount, balance_amount, commission_amount, created_at`

func scanOrder(row pgx.Row) (*Order, error) {
	var o Order
	err := row.Scan(&o.ID, &o.CustomerID, &o.BakerID, &o.ProductID, &o.Status,
		&o.EventDate, &o.DeliveryAddress, &o.TotalAmount, &o.DepositAmount,
		&o.BalanceAmount, &o.CommissionAmount, &o.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &o, nil
}

// Create inserts an order and its specs atomically and returns the full order.
func (r *Repository) Create(ctx context.Context, o *Order, eventDate time.Time, lat, lng *float64, specs []OrderSpec) (*Order, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx) //nolint:errcheck // no-op once committed

	created, err := scanOrder(tx.QueryRow(ctx,
		`INSERT INTO orders
		    (customer_id, baker_id, product_id, status, event_date, delivery_address, delivery_location)
		 VALUES (
		    $1, $2, NULLIF($3, '')::uuid, $4, $5, NULLIF($6, ''),
		    CASE WHEN $7::float8 IS NOT NULL AND $8::float8 IS NOT NULL
		         THEN ST_SetSRID(ST_MakePoint($8, $7), 4326)::geography END
		 )
		 RETURNING `+orderColumns,
		o.CustomerID, o.BakerID, o.ProductID, o.Status, eventDate, o.DeliveryAddress, lat, lng,
	))
	if err != nil {
		return nil, err
	}

	for _, s := range specs {
		if _, err := tx.Exec(ctx,
			`INSERT INTO order_specs (order_id, key, value) VALUES ($1, $2, $3)`,
			created.ID, s.Key, s.Value,
		); err != nil {
			return nil, err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	created.Specs = specs
	return created, nil
}

// GetByID fetches a single order without specs.
func (r *Repository) GetByID(ctx context.Context, id string) (*Order, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanOrder(r.db.QueryRow(ctx, `SELECT `+orderColumns+` FROM orders WHERE id = $1`, id))
}

// GetSpecs returns an order's spec attributes.
func (r *Repository) GetSpecs(ctx context.Context, orderID string) ([]OrderSpec, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rows, err := r.db.Query(ctx,
		`SELECT id, order_id, key, COALESCE(value, '') FROM order_specs WHERE order_id = $1 ORDER BY key`,
		orderID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]OrderSpec, 0)
	for rows.Next() {
		var s OrderSpec
		if err := rows.Scan(&s.ID, &s.OrderID, &s.Key, &s.Value); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// List returns orders for a user acting as customer and/or baker.
func (r *Repository) List(ctx context.Context, userID, bakerID string, f ListFilter) ([]Order, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	args := []any{}
	add := func(v any) string { args = append(args, v); return "$" + strconv.Itoa(len(args)) }

	var scope string
	switch f.Role {
	case "baker":
		if bakerID == "" {
			return []Order{}, nil
		}
		scope = "baker_id = " + add(bakerID)
	case "all":
		if bakerID == "" {
			scope = "customer_id = " + add(userID)
		} else {
			scope = "(customer_id = " + add(userID) + " OR baker_id = " + add(bakerID) + ")"
		}
	default: // customer
		scope = "customer_id = " + add(userID)
	}

	q := `SELECT ` + orderColumns + ` FROM orders WHERE ` + scope
	if f.Status != "" {
		q += " AND status = " + add(f.Status)
	}
	q += " ORDER BY created_at DESC LIMIT " + add(f.Limit) + " OFFSET " + add(f.Offset)

	rows, err := r.db.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Order, 0)
	for rows.Next() {
		var o Order
		if err := rows.Scan(&o.ID, &o.CustomerID, &o.BakerID, &o.ProductID, &o.Status,
			&o.EventDate, &o.DeliveryAddress, &o.TotalAmount, &o.DepositAmount,
			&o.BalanceAmount, &o.CommissionAmount, &o.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, o)
	}
	return out, rows.Err()
}

// UpdateStatus transitions an order to a new status.
func (r *Repository) UpdateStatus(ctx context.Context, id, status string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	_, err := r.db.Exec(ctx, `UPDATE orders SET status = $2, updated_at = now() WHERE id = $1`, id, status)
	return err
}

// BakerIDForUser resolves the baker_profiles.id owned by userID, or "" if none.
func (r *Repository) BakerIDForUser(ctx context.Context, userID string) (string, error) {
	if r.db == nil {
		return "", pkg.ErrNotImplemented
	}
	var id string
	err := r.db.QueryRow(ctx, `SELECT id FROM baker_profiles WHERE user_id = $1`, userID).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", nil
	}
	return id, err
}

// BakerScheduling returns the scheduling-relevant fields of a baker profile.
func (r *Repository) BakerScheduling(ctx context.Context, bakerID string) (*bakerScheduling, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	var bs bakerScheduling
	err := r.db.QueryRow(ctx,
		`SELECT user_id, status, lead_time_days, daily_order_capacity FROM baker_profiles WHERE id = $1`,
		bakerID,
	).Scan(&bs.UserID, &bs.Status, &bs.LeadTimeDays, &bs.DailyCapacity)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &bs, nil
}

// IsBlackout reports whether a baker has blacked out the given date.
func (r *Repository) IsBlackout(ctx context.Context, bakerID string, date time.Time) (bool, error) {
	if r.db == nil {
		return false, pkg.ErrNotImplemented
	}
	var exists bool
	err := r.db.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM baker_blackout_dates WHERE baker_id = $1 AND date = $2)`,
		bakerID, date,
	).Scan(&exists)
	return exists, err
}

// CountOrdersOn counts a baker's non-cancelled orders booked for a given date.
func (r *Repository) CountOrdersOn(ctx context.Context, bakerID string, date time.Time) (int, error) {
	if r.db == nil {
		return 0, pkg.ErrNotImplemented
	}
	var n int
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM orders
		  WHERE baker_id = $1 AND event_date = $2
		    AND status NOT IN ('`+StatusCancelled+`', '`+StatusRefunded+`')`,
		bakerID, date,
	).Scan(&n)
	return n, err
}
