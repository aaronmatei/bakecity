package admin

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Baker moderation state values (mirror internal/bakers).
const (
	statusPending  = "pending"
	statusApproved = "approved"
	kycApproved    = "approved"
)

// Repository provides admin-scoped queries across domains.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const bakerSummaryColumns = `b.id, b.user_id, b.business_name, b.status, b.kyc_status,
	u.phone, COALESCE(u.email, ''), b.created_at`

func scanBakerSummary(row pgx.Row) (*BakerSummary, error) {
	var s BakerSummary
	err := row.Scan(&s.ID, &s.UserID, &s.BusinessName, &s.Status, &s.KYCStatus,
		&s.Phone, &s.Email, &s.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &s, nil
}

// ListPendingBakers returns baker profiles awaiting approval, oldest first.
func (r *Repository) ListPendingBakers(ctx context.Context) ([]BakerSummary, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rows, err := r.db.Query(ctx,
		`SELECT `+bakerSummaryColumns+`
		   FROM baker_profiles b JOIN users u ON u.id = b.user_id
		  WHERE b.status = $1
		  ORDER BY b.created_at`,
		statusPending,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]BakerSummary, 0)
	for rows.Next() {
		var s BakerSummary
		if err := rows.Scan(&s.ID, &s.UserID, &s.BusinessName, &s.Status, &s.KYCStatus,
			&s.Phone, &s.Email, &s.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, s)
	}
	return out, rows.Err()
}

// ApproveBaker marks a baker profile approved (and its KYC approved), returning
// the updated summary. Returns ErrNotFound if no such profile exists.
func (r *Repository) ApproveBaker(ctx context.Context, id string) (*BakerSummary, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanBakerSummary(r.db.QueryRow(ctx,
		`UPDATE baker_profiles b
		    SET status = $2, kyc_status = $3, updated_at = now()
		   FROM users u
		  WHERE b.id = $1 AND u.id = b.user_id
		RETURNING `+bakerSummaryColumns,
		id, statusApproved, kycApproved,
	))
}
