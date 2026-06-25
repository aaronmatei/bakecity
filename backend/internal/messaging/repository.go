package messaging

import (
	"context"
	"errors"
	"net/http"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists messaging domain data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// ThreadForOrder returns the order's thread id, creating it on first use.
func (r *Repository) ThreadForOrder(ctx context.Context, orderID string) (string, error) {
	if r.db == nil {
		return "", pkg.ErrNotImplemented
	}
	var id string
	err := r.db.QueryRow(ctx,
		`INSERT INTO message_threads (order_id) VALUES ($1)
		 ON CONFLICT (order_id) DO UPDATE SET order_id = EXCLUDED.order_id
		 RETURNING id`,
		orderID,
	).Scan(&id)
	return id, err
}

// ThreadIDByOrder returns the order's thread id, or ErrNotFound if none exists.
func (r *Repository) ThreadIDByOrder(ctx context.Context, orderID string) (string, error) {
	if r.db == nil {
		return "", pkg.ErrNotImplemented
	}
	var id string
	err := r.db.QueryRow(ctx, `SELECT id FROM message_threads WHERE order_id = $1`, orderID).Scan(&id)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", pkg.ErrNotFound
	}
	return id, err
}

// Insert adds a message to a thread. A non-empty mediaID that does not exist
// yields a 422 APIError.
func (r *Repository) Insert(ctx context.Context, threadID, senderID, body, mediaID string) (*Message, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	var m Message
	err := r.db.QueryRow(ctx,
		`INSERT INTO messages (thread_id, sender_id, body, media_id)
		 VALUES ($1, $2, NULLIF($3, ''), NULLIF($4, '')::uuid)
		 RETURNING id, thread_id, sender_id, COALESCE(body, ''), COALESCE(media_id::text, ''), created_at`,
		threadID, senderID, body, mediaID,
	).Scan(&m.ID, &m.ThreadID, &m.SenderID, &m.Body, &m.MediaID, &m.CreatedAt)
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) && pgErr.Code == "23503" { // foreign_key_violation (media_id)
		return nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation, "media_id does not exist")
	}
	if err != nil {
		return nil, err
	}
	return &m, nil
}

// List returns a thread's messages in chronological order.
func (r *Repository) List(ctx context.Context, threadID string, limit, offset int) ([]Message, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rows, err := r.db.Query(ctx,
		`SELECT id, thread_id, sender_id, COALESCE(body, ''), COALESCE(media_id::text, ''), created_at
		   FROM messages WHERE thread_id = $1
		  ORDER BY created_at ASC, id ASC
		  LIMIT $2 OFFSET $3`,
		threadID, limit, offset,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Message, 0)
	for rows.Next() {
		var m Message
		if err := rows.Scan(&m.ID, &m.ThreadID, &m.SenderID, &m.Body, &m.MediaID, &m.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, m)
	}
	return out, rows.Err()
}
