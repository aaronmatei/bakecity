package media

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists media domain data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const mediaColumns = `id, COALESCE(order_id::text, ''), owner_id, kind, s3_key,
	COALESCE(thumb_key, ''), status, created_at`

func scanMedia(row pgx.Row) (*Media, error) {
	var m Media
	err := row.Scan(&m.ID, &m.OrderID, &m.OwnerID, &m.Kind, &m.S3Key,
		&m.ThumbKey, &m.Status, &m.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &m, nil
}

// Create inserts a pending media record owned by ownerID and returns it.
func (r *Repository) Create(ctx context.Context, ownerID, orderID, kind, s3Key string) (*Media, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanMedia(r.db.QueryRow(ctx,
		`INSERT INTO media (order_id, owner_id, kind, s3_key, status)
		 VALUES (NULLIF($1, '')::uuid, $2, $3, $4, $5)
		 RETURNING `+mediaColumns,
		orderID, ownerID, kind, s3Key, StatusPending,
	))
}

// GetByID fetches a single media record.
func (r *Repository) GetByID(ctx context.Context, id string) (*Media, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanMedia(r.db.QueryRow(ctx, `SELECT `+mediaColumns+` FROM media WHERE id = $1`, id))
}

// SetStatus updates a media record's lifecycle status.
func (r *Repository) SetStatus(ctx context.Context, id, status string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	_, err := r.db.Exec(ctx, `UPDATE media SET status = $2 WHERE id = $1`, id, status)
	return err
}
