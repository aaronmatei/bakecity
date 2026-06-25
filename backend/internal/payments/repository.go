package payments

import (
	"github.com/jackc/pgx/v5/pgxpool"
)

// Repository persists payment records.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}
