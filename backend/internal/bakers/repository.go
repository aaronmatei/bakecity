package bakers

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// parsedBlackout is a validated blackout date ready for persistence.
type parsedBlackout struct {
	Date   time.Time
	Reason string
}

// roleBakerBit mirrors users.role_mask bit for the baker role (see middleware.RoleBaker).
const roleBakerBit = 2

// Repository persists bakers domain data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// profileColumns selects a full BakerProfile, decoding the geography point into
// lat/lng (NULL when no location is set).
const profileColumns = `id, user_id, business_name, COALESCE(bio, ''), delivery_radius_km,
	status, kyc_status, lead_time_days, daily_order_capacity,
	ST_Y(location::geometry), ST_X(location::geometry), created_at, updated_at`

func scanProfile(row pgx.Row) (*BakerProfile, error) {
	var b BakerProfile
	err := row.Scan(&b.ID, &b.UserID, &b.BusinessName, &b.Bio, &b.DeliveryRadiusKM,
		&b.Status, &b.KYCStatus, &b.LeadTimeDays, &b.DailyCapacity,
		&b.Lat, &b.Lng, &b.CreatedAt, &b.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &b, nil
}

// Create inserts a baker profile for userID and flips the baker role bit on the
// user, atomically. Returns the new profile.
func (r *Repository) Create(ctx context.Context, userID string, req CreateBakerRequest) (*BakerProfile, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback(ctx) //nolint:errcheck // no-op once committed

	row := tx.QueryRow(ctx,
		`INSERT INTO baker_profiles
		    (user_id, business_name, bio, location, delivery_radius_km, lead_time_days, daily_order_capacity)
		 VALUES (
		    $1, $2, NULLIF($3, ''),
		    CASE WHEN $4::float8 IS NOT NULL AND $5::float8 IS NOT NULL
		         THEN ST_SetSRID(ST_MakePoint($5, $4), 4326)::geography END,
		    COALESCE($6, 10), COALESCE($7, 1), COALESCE($8, 10)
		 )
		 RETURNING `+profileColumns,
		userID, req.BusinessName, req.Bio, req.Lat, req.Lng,
		req.DeliveryRadiusKM, req.LeadTimeDays, req.DailyCapacity,
	)
	b, err := scanProfile(row)
	if isUniqueViolation(err) {
		return nil, pkg.ErrConflict
	}
	if err != nil {
		return nil, err
	}

	if _, err := tx.Exec(ctx,
		`UPDATE users SET role_mask = role_mask | $2, updated_at = now() WHERE id = $1`,
		userID, roleBakerBit,
	); err != nil {
		return nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return nil, err
	}
	return b, nil
}

// GetByID fetches a baker profile.
func (r *Repository) GetByID(ctx context.Context, id string) (*BakerProfile, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanProfile(r.db.QueryRow(ctx, `SELECT `+profileColumns+` FROM baker_profiles WHERE id = $1`, id))
}

// Update applies a partial update to a baker profile and returns the result.
func (r *Repository) Update(ctx context.Context, id string, req UpdateBakerRequest) (*BakerProfile, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	row := r.db.QueryRow(ctx,
		`UPDATE baker_profiles SET
		    business_name        = COALESCE($2, business_name),
		    bio                  = COALESCE($3, bio),
		    delivery_radius_km   = COALESCE($4, delivery_radius_km),
		    lead_time_days       = COALESCE($5, lead_time_days),
		    daily_order_capacity = COALESCE($6, daily_order_capacity),
		    location = CASE WHEN $7::float8 IS NOT NULL AND $8::float8 IS NOT NULL
		                    THEN ST_SetSRID(ST_MakePoint($8, $7), 4326)::geography
		                    ELSE location END,
		    updated_at = now()
		  WHERE id = $1
		RETURNING `+profileColumns,
		id, req.BusinessName, req.Bio, req.DeliveryRadiusKM,
		req.LeadTimeDays, req.DailyCapacity, req.Lat, req.Lng,
	)
	return scanProfile(row)
}

// SubmitKYC marks the profile's KYC as submitted (pending admin review).
func (r *Repository) SubmitKYC(ctx context.Context, id string) (*BakerProfile, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanProfile(r.db.QueryRow(ctx,
		`UPDATE baker_profiles SET kyc_status = $2, updated_at = now()
		  WHERE id = $1 RETURNING `+profileColumns,
		id, KYCSubmitted,
	))
}

// ListBlackoutDates returns the blackout dates for a baker, oldest first.
func (r *Repository) ListBlackoutDates(ctx context.Context, bakerID string) ([]BlackoutDate, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rows, err := r.db.Query(ctx,
		`SELECT id, baker_id, date, COALESCE(reason, '')
		   FROM baker_blackout_dates WHERE baker_id = $1 ORDER BY date`,
		bakerID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	dates := make([]BlackoutDate, 0)
	for rows.Next() {
		var d BlackoutDate
		if err := rows.Scan(&d.ID, &d.BakerID, &d.Date, &d.Reason); err != nil {
			return nil, err
		}
		dates = append(dates, d)
	}
	return dates, rows.Err()
}

// SetAvailability updates scheduling parameters (when provided) and replaces the
// baker's blackout-date set, atomically.
func (r *Repository) SetAvailability(ctx context.Context, bakerID string, leadTime, capacity *int, dates []parsedBlackout) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck // no-op once committed

	if _, err := tx.Exec(ctx,
		`UPDATE baker_profiles SET
		    lead_time_days       = COALESCE($2, lead_time_days),
		    daily_order_capacity = COALESCE($3, daily_order_capacity),
		    updated_at = now()
		  WHERE id = $1`,
		bakerID, leadTime, capacity,
	); err != nil {
		return err
	}

	if _, err := tx.Exec(ctx, `DELETE FROM baker_blackout_dates WHERE baker_id = $1`, bakerID); err != nil {
		return err
	}
	for _, d := range dates {
		if _, err := tx.Exec(ctx,
			`INSERT INTO baker_blackout_dates (baker_id, date, reason)
			 VALUES ($1, $2, NULLIF($3, ''))
			 ON CONFLICT (baker_id, date) DO UPDATE SET reason = EXCLUDED.reason`,
			bakerID, d.Date, d.Reason,
		); err != nil {
			return err
		}
	}
	return tx.Commit(ctx)
}

// isUniqueViolation reports whether err is a Postgres unique-constraint error.
func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
