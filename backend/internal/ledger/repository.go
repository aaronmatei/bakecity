package ledger

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository persists double-entry ledger data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// PostTransaction records a balanced set of debit/credit entries atomically.
// Entries must sum to zero (sum(debit) == sum(credit)).
func (r *Repository) PostTransaction(ctx context.Context, txn *Transaction, entries []Entry) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	return pkg.ErrNotImplemented
}
