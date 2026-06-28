package analytics

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists analytics domain data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// Overview computes the platform analytics snapshot. GMV and platform revenue
// are realized only on COMPLETED orders.
func (r *Repository) Overview(ctx context.Context) (*PlatformStats, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	var s PlatformStats
	if err := r.db.QueryRow(ctx,
		`SELECT
		    COUNT(*),
		    COUNT(*) FILTER (WHERE status = 'COMPLETED'),
		    COALESCE(SUM(total_amount) FILTER (WHERE status = 'COMPLETED'), 0),
		    COALESCE(SUM(commission_amount) FILTER (WHERE status = 'COMPLETED'), 0)
		 FROM orders`,
	).Scan(&s.TotalOrders, &s.CompletedOrders, &s.GMV, &s.PlatformRevenue); err != nil {
		return nil, err
	}
	if err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM baker_profiles WHERE status = 'approved'`,
	).Scan(&s.ActiveBakers); err != nil {
		return nil, err
	}
	if err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM disputes WHERE status = 'open'`,
	).Scan(&s.OpenDisputes); err != nil {
		return nil, err
	}
	return &s, nil
}
