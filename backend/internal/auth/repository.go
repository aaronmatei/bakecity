package auth

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists authentication credentials. Password hashes are stored in
// the user_credentials table (see migrations).
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// CreateUser inserts a user and its credential, returning the new user id.
func (r *Repository) CreateUser(ctx context.Context, phone, email, passwordHash string, roleMask int) (string, error) {
	if r.db == nil {
		return "", pkg.ErrNotImplemented
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return "", err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var userID string
	var emailArg any
	if email != "" {
		emailArg = email
	}
	err = tx.QueryRow(ctx,
		`INSERT INTO users (role_mask, phone, email) VALUES ($1, $2, $3) RETURNING id`,
		roleMask, phone, emailArg,
	).Scan(&userID)
	if err != nil {
		return "", err
	}

	_, err = tx.Exec(ctx,
		`INSERT INTO user_credentials (user_id, password_hash) VALUES ($1, $2)`,
		userID, passwordHash,
	)
	if err != nil {
		return "", err
	}

	if err := tx.Commit(ctx); err != nil {
		return "", err
	}
	return userID, nil
}

// GetCredentialByIdentifier looks up a credential by phone or email.
func (r *Repository) GetCredentialByIdentifier(ctx context.Context, identifier string) (*Credential, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	var cred Credential
	err := r.db.QueryRow(ctx,
		`SELECT u.id, c.password_hash, u.role_mask
		   FROM users u
		   JOIN user_credentials c ON c.user_id = u.id
		  WHERE u.phone = $1 OR u.email = $1`,
		identifier,
	).Scan(&cred.UserID, &cred.PasswordHash, &cred.RoleMask)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &cred, nil
}
