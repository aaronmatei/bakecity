package notifications

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists notifications domain data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const notificationColumns = `id, user_id, channel, type, payload, read_at, created_at`

// Create inserts an in-app notification record.
func (r *Repository) Create(ctx context.Context, userID, channel, notifType string, payload []byte) (*Notification, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	if len(payload) == 0 {
		payload = []byte("{}")
	}
	var n Notification
	err := r.db.QueryRow(ctx,
		`INSERT INTO notifications (user_id, channel, type, payload)
		 VALUES ($1, $2, $3, $4)
		 RETURNING `+notificationColumns,
		userID, channel, notifType, payload,
	).Scan(&n.ID, &n.UserID, &n.Channel, &n.Type, &n.Payload, &n.ReadAt, &n.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &n, nil
}

// ListByUser returns a user's notifications, newest first; optionally only
// unread ones.
func (r *Repository) ListByUser(ctx context.Context, userID string, unreadOnly bool, limit, offset int) ([]Notification, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	q := `SELECT ` + notificationColumns + ` FROM notifications WHERE user_id = $1`
	if unreadOnly {
		q += ` AND read_at IS NULL`
	}
	q += ` ORDER BY created_at DESC, id DESC LIMIT $2 OFFSET $3`

	rows, err := r.db.Query(ctx, q, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]Notification, 0)
	for rows.Next() {
		var n Notification
		if err := rows.Scan(&n.ID, &n.UserID, &n.Channel, &n.Type, &n.Payload, &n.ReadAt, &n.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, n)
	}
	return out, rows.Err()
}

// MarkRead marks one notification read for its owner. Returns ErrNotFound if no
// matching unread/owned notification exists.
func (r *Repository) MarkRead(ctx context.Context, id, userID string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	tag, err := r.db.Exec(ctx,
		`UPDATE notifications SET read_at = now() WHERE id = $1 AND user_id = $2 AND read_at IS NULL`,
		id, userID,
	)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		return pkg.ErrNotFound
	}
	return nil
}

// MarkAllRead marks all of a user's unread notifications read, returning the
// number updated.
func (r *Repository) MarkAllRead(ctx context.Context, userID string) (int64, error) {
	if r.db == nil {
		return 0, pkg.ErrNotImplemented
	}
	tag, err := r.db.Exec(ctx,
		`UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL`, userID)
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// UnreadCount returns the number of unread notifications for a user.
func (r *Repository) UnreadCount(ctx context.Context, userID string) (int, error) {
	if r.db == nil {
		return 0, pkg.ErrNotImplemented
	}
	var n int
	err := r.db.QueryRow(ctx,
		`SELECT COUNT(*) FROM notifications WHERE user_id = $1 AND read_at IS NULL`, userID).Scan(&n)
	return n, err
}

// RegisterDeviceToken upserts a device's push token for a user. The token is
// the primary key, so re-registering the same token (e.g. the same device after
// a different user logs in) reassigns it to the current user and refreshes
// updated_at.
func (r *Repository) RegisterDeviceToken(ctx context.Context, userID, token, platform string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	if platform == "" {
		platform = "unknown"
	}
	_, err := r.db.Exec(ctx,
		`INSERT INTO device_tokens (token, user_id, platform)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (token) DO UPDATE
		   SET user_id = EXCLUDED.user_id,
		       platform = EXCLUDED.platform,
		       updated_at = now()`,
		token, userID, platform,
	)
	return err
}

// DeleteDeviceToken removes a device token for a user (e.g. on logout). It is
// scoped to the owner so one user can't unregister another's device.
func (r *Repository) DeleteDeviceToken(ctx context.Context, userID, token string) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	_, err := r.db.Exec(ctx,
		`DELETE FROM device_tokens WHERE token = $1 AND user_id = $2`, token, userID)
	return err
}

// DeviceTokensByUser returns the push tokens registered to a user's devices. A
// production push Sender resolves a user's tokens through this before
// delivering to FCM.
func (r *Repository) DeviceTokensByUser(ctx context.Context, userID string) ([]string, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	rows, err := r.db.Query(ctx,
		`SELECT token FROM device_tokens WHERE user_id = $1`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	tokens := make([]string, 0)
	for rows.Next() {
		var t string
		if err := rows.Scan(&t); err != nil {
			return nil, err
		}
		tokens = append(tokens, t)
	}
	return tokens, rows.Err()
}

// UserPhone returns a user's phone number (for SMS), or ErrNotFound.
func (r *Repository) UserPhone(ctx context.Context, userID string) (string, error) {
	if r.db == nil {
		return "", pkg.ErrNotImplemented
	}
	var phone string
	err := r.db.QueryRow(ctx, `SELECT phone FROM users WHERE id = $1`, userID).Scan(&phone)
	if errors.Is(err, pgx.ErrNoRows) {
		return "", pkg.ErrNotFound
	}
	return phone, err
}
