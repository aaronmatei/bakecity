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

const orderColumns = `id, order_number, customer_id, baker_id, COALESCE(product_id::text, ''), status,
	event_date, COALESCE(delivery_address, ''),
	total_amount, deposit_amount, balance_amount, commission_amount,
	COALESCE(fulfillment_type, 'delivery'), delivery_fee, created_at`

// nameExprs appends the counterparty display names (customer's name, bakery's
// business name) for list/detail reads. Leading comma so it follows orderColumns.
const nameExprs = `,
	COALESCE((SELECT name FROM users WHERE id = orders.customer_id), ''),
	COALESCE((SELECT business_name FROM baker_profiles WHERE id = orders.baker_id), '')`

func scanOrder(row pgx.Row) (*Order, error) {
	var o Order
	err := row.Scan(&o.ID, &o.OrderNumber, &o.CustomerID, &o.BakerID, &o.ProductID, &o.Status,
		&o.EventDate, &o.DeliveryAddress, &o.TotalAmount, &o.DepositAmount,
		&o.BalanceAmount, &o.CommissionAmount, &o.FulfillmentType, &o.DeliveryFee, &o.CreatedAt)
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
		    (customer_id, baker_id, product_id, status, event_date, delivery_address,
		     fulfillment_type, delivery_location)
		 VALUES (
		    $1, $2, NULLIF($3, '')::uuid, $4, $5, NULLIF($6, ''),
		    COALESCE(NULLIF($9, ''), 'delivery'),
		    CASE WHEN $7::float8 IS NOT NULL AND $8::float8 IS NOT NULL
		         THEN ST_SetSRID(ST_MakePoint($8, $7), 4326)::geography END
		 )
		 RETURNING `+orderColumns,
		o.CustomerID, o.BakerID, o.ProductID, o.Status, eventDate, o.DeliveryAddress, lat, lng,
		o.FulfillmentType,
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
	var o Order
	err := r.db.QueryRow(ctx, `SELECT `+orderColumns+nameExprs+` FROM orders WHERE id = $1`, id).
		Scan(&o.ID, &o.OrderNumber, &o.CustomerID, &o.BakerID, &o.ProductID, &o.Status,
			&o.EventDate, &o.DeliveryAddress, &o.TotalAmount, &o.DepositAmount,
			&o.BalanceAmount, &o.CommissionAmount, &o.FulfillmentType, &o.DeliveryFee,
			&o.CreatedAt, &o.CustomerName, &o.BakerName)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &o, nil
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

	q := `SELECT ` + orderColumns + nameExprs + ` FROM orders WHERE ` + scope
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
		if err := rows.Scan(&o.ID, &o.OrderNumber, &o.CustomerID, &o.BakerID, &o.ProductID, &o.Status,
			&o.EventDate, &o.DeliveryAddress, &o.TotalAmount, &o.DepositAmount,
			&o.BalanceAmount, &o.CommissionAmount, &o.FulfillmentType, &o.DeliveryFee,
			&o.CreatedAt, &o.CustomerName, &o.BakerName); err != nil {
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

// ProductInfo is the pricing/identity of a product (optionally a chosen size),
// used by buy-now and cart checkout.
type ProductInfo struct {
	Price       float64
	IsCustom    bool
	OnOffer     bool
	DiscountPct int
	BakerID     string
	Title       string
	SizeLabel   string
}

// ProductPricing returns a product's list price/identity. When sizeID is set and
// belongs to the product, that size's price/label is used.
func (r *Repository) ProductPricing(ctx context.Context, productID, sizeID string) (ProductInfo, error) {
	if r.db == nil {
		return ProductInfo{}, pkg.ErrNotImplemented
	}
	var info ProductInfo
	var dp *int
	err := r.db.QueryRow(ctx,
		`SELECT base_price, is_custom, is_on_offer, discount_pct, baker_id, title FROM products WHERE id = $1`,
		productID,
	).Scan(&info.Price, &info.IsCustom, &info.OnOffer, &dp, &info.BakerID, &info.Title)
	if errors.Is(err, pgx.ErrNoRows) {
		return ProductInfo{}, pkg.ErrNotFound
	}
	if err != nil {
		return ProductInfo{}, err
	}
	if dp != nil {
		info.DiscountPct = *dp
	}
	if sizeID != "" {
		var sp float64
		var lbl string
		if e := r.db.QueryRow(ctx,
			`SELECT price, label FROM product_sizes WHERE id = $1 AND product_id = $2`,
			sizeID, productID,
		).Scan(&sp, &lbl); e == nil {
			info.Price = sp
			info.SizeLabel = lbl
		}
	}
	return info, nil
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

// BakerInsights aggregates a baker's order book: counts by status, completed
// revenue (gross and net of commission), and the top 5 products by orders.
func (r *Repository) BakerInsights(ctx context.Context, bakerID string) (*BakerInsights, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	out := &BakerInsights{
		StatusCounts: map[string]int{},
		TopProducts:  []ProductPerf{},
		RevenueTrend: []TrendPoint{},
	}

	rows, err := r.db.Query(ctx,
		`SELECT status, COUNT(*) FROM orders WHERE baker_id = $1 GROUP BY status`, bakerID)
	if err != nil {
		return nil, err
	}
	for rows.Next() {
		var s string
		var n int
		if err := rows.Scan(&s, &n); err != nil {
			rows.Close()
			return nil, err
		}
		out.StatusCounts[s] = n
	}
	rows.Close()
	if err := rows.Err(); err != nil {
		return nil, err
	}

	if err := r.db.QueryRow(ctx,
		`SELECT COUNT(*), COALESCE(SUM(total_amount), 0),
		        COALESCE(SUM(total_amount - commission_amount), 0)
		   FROM orders WHERE baker_id = $1 AND status = 'COMPLETED'`,
		bakerID,
	).Scan(&out.CompletedOrders, &out.GrossRevenue, &out.NetRevenue); err != nil {
		return nil, err
	}

	if err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM favorite_bakers WHERE baker_id = $1`, bakerID,
	).Scan(&out.FollowerCount); err != nil {
		return nil, err
	}

	prows, err := r.db.Query(ctx,
		`SELECT o.product_id, p.title, COUNT(*), COALESCE(SUM(o.total_amount), 0)
		   FROM orders o JOIN products p ON p.id = o.product_id
		  WHERE o.baker_id = $1
		  GROUP BY o.product_id, p.title
		  ORDER BY COUNT(*) DESC, SUM(o.total_amount) DESC
		  LIMIT 5`, bakerID)
	if err != nil {
		return nil, err
	}
	for prows.Next() {
		var p ProductPerf
		if err := prows.Scan(&p.ProductID, &p.Title, &p.OrderCount, &p.Revenue); err != nil {
			prows.Close()
			return nil, err
		}
		out.TopProducts = append(out.TopProducts, p)
	}
	prows.Close()
	if err := prows.Err(); err != nil {
		return nil, err
	}

	// Net revenue per month for the last 6 months (zero-filled so the sparkline
	// has a steady cadence).
	trows, err := r.db.Query(ctx,
		`SELECT to_char(m, 'YYYY-MM'),
		        COALESCE(SUM(o.total_amount - o.commission_amount), 0)
		   FROM generate_series(
		            date_trunc('month', now()) - interval '5 months',
		            date_trunc('month', now()),
		            interval '1 month') AS m
		   LEFT JOIN orders o
		     ON date_trunc('month', o.created_at) = m
		    AND o.baker_id = $1 AND o.status = 'COMPLETED'
		  GROUP BY m ORDER BY m`, bakerID)
	if err != nil {
		return nil, err
	}
	defer trows.Close()
	for trows.Next() {
		var tp TrendPoint
		if err := trows.Scan(&tp.Period, &tp.Revenue); err != nil {
			return nil, err
		}
		out.RevenueTrend = append(out.RevenueTrend, tp)
	}
	return out, trows.Err()
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

// CountOrdersOn counts a baker's non-cancelled orders booked for a given date,
// optionally excluding one order id (e.g. the order being re-validated).
func (r *Repository) CountOrdersOn(ctx context.Context, bakerID string, date time.Time, excludeOrderID string) (int, error) {
	if r.db == nil {
		return 0, pkg.ErrNotImplemented
	}
	var n int
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM orders
		  WHERE baker_id = $1 AND event_date = $2
		    AND status NOT IN ('`+StatusCancelled+`', '`+StatusRefunded+`')
		    AND ($3 = '' OR id <> $3::uuid)`,
		bakerID, date, excludeOrderID,
	).Scan(&n)
	return n, err
}

// SetAmountsAndStatus records the financial breakdown and transitions an order's
// status in a single update.
func (r *Repository) SetAmountsAndStatus(ctx context.Context, id string, total, deposit, balance, commission, deliveryFee float64, status string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	_, err := r.db.Exec(ctx,
		`UPDATE orders
		    SET total_amount = $2, deposit_amount = $3, balance_amount = $4,
		        commission_amount = $5, delivery_fee = $6, status = $7, updated_at = now()
		  WHERE id = $1`,
		id, total, deposit, balance, commission, deliveryFee, status,
	)
	return err
}
