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
	COALESCE(thumb_key, ''), status, COALESCE(stage, ''), COALESCE(mime_type, ''),
	created_at`

func scanMedia(row pgx.Row) (*Media, error) {
	var m Media
	err := row.Scan(&m.ID, &m.OrderID, &m.OwnerID, &m.Kind, &m.S3Key,
		&m.ThumbKey, &m.Status, &m.Stage, &m.MimeType, &m.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &m, nil
}

// Create inserts a pending media record owned by ownerID and returns it. stage
// and mimeType are optional (empty stores NULL).
func (r *Repository) Create(ctx context.Context, ownerID, orderID, kind, s3Key, stage, mimeType string) (*Media, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanMedia(r.db.QueryRow(ctx,
		`INSERT INTO media (order_id, owner_id, kind, s3_key, status, stage, mime_type)
		 VALUES (NULLIF($1, '')::uuid, $2, $3, $4, $5, NULLIF($6, ''), NULLIF($7, ''))
		 RETURNING `+mediaColumns,
		orderID, ownerID, kind, s3Key, StatusPending, stage, mimeType,
	))
}

// GetByID fetches a single media record.
func (r *Repository) GetByID(ctx context.Context, id string) (*Media, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanMedia(r.db.QueryRow(ctx, `SELECT `+mediaColumns+` FROM media WHERE id = $1`, id))
}

// ListByOrder returns an order's media, newest first. When kind is non-empty it
// is filtered to that purpose (e.g. "reference"). Only uploaded media is
// returned — pending records whose upload never completed are excluded.
func (r *Repository) ListByOrder(ctx context.Context, orderID, kind string) ([]Media, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	q := `SELECT ` + mediaColumns + ` FROM media
	      WHERE order_id = $1 AND status = $2`
	args := []any{orderID, StatusUploaded}
	if kind != "" {
		q += ` AND kind = $3`
		args = append(args, kind)
	}
	q += ` ORDER BY created_at DESC, id DESC`

	rows, err := r.db.Query(ctx, q, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Media, 0)
	for rows.Next() {
		var m Media
		if err := rows.Scan(&m.ID, &m.OrderID, &m.OwnerID, &m.Kind, &m.S3Key,
			&m.ThumbKey, &m.Status, &m.Stage, &m.MimeType, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// ListByOwnerKind returns a user's uploaded media of a given kind that is not
// tied to an order (owner-scoped, e.g. KYC identity documents), newest first.
func (r *Repository) ListByOwnerKind(ctx context.Context, ownerID, kind string) ([]Media, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rows, err := r.db.Query(ctx,
		`SELECT `+mediaColumns+` FROM media
		  WHERE owner_id = $1 AND kind = $2 AND status = $3 AND order_id IS NULL
		  ORDER BY created_at DESC, id DESC`,
		ownerID, kind, StatusUploaded,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Media, 0)
	for rows.Next() {
		var m Media
		if err := rows.Scan(&m.ID, &m.OrderID, &m.OwnerID, &m.Kind, &m.S3Key,
			&m.ThumbKey, &m.Status, &m.Stage, &m.MimeType, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}

// SetStatus updates a media record's lifecycle status.
func (r *Repository) SetStatus(ctx context.Context, id, status string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	_, err := r.db.Exec(ctx, `UPDATE media SET status = $2 WHERE id = $1`, id, status)
	return err
}
