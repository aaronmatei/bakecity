package users

import (
	"context"
	"errors"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists users domain data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

const userColumns = `id, role_mask, phone, COALESCE(email, ''), phone_verified, created_at, updated_at`

func scanUser(row pgx.Row) (*User, error) {
	var u User
	err := row.Scan(&u.ID, &u.RoleMask, &u.Phone, &u.Email, &u.PhoneVerified, &u.CreatedAt, &u.UpdatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, pkg.ErrNotFound
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

// GetByID fetches a single user by id.
func (r *Repository) GetByID(ctx context.Context, id string) (*User, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	return scanUser(r.db.QueryRow(ctx, `SELECT `+userColumns+` FROM users WHERE id = $1`, id))
}

// UpdateProfile applies a partial update to the user's email and/or phone.
// Empty string arguments leave the existing value untouched.
func (r *Repository) UpdateProfile(ctx context.Context, id, email, phone string) (*User, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	row := r.db.QueryRow(ctx,
		`UPDATE users
		    SET email = COALESCE(NULLIF($2, ''), email),
		        phone = COALESCE(NULLIF($3, ''), phone),
		        updated_at = now()
		  WHERE id = $1
		RETURNING `+userColumns,
		id, email, phone,
	)
	u, err := scanUser(row)
	if isUniqueViolation(err) {
		return nil, pkg.ErrConflict
	}
	return u, err
}

// isUniqueViolation reports whether err is a Postgres unique-constraint error.
func isUniqueViolation(err error) bool {
	var pgErr *pgconn.PgError
	return errors.As(err, &pgErr) && pgErr.Code == "23505"
}
