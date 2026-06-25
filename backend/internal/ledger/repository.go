package ledger

import (
	"context"
	"errors"
	"fmt"
	"math"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// ErrUnbalanced indicates a transaction whose debits and credits do not match.
var ErrUnbalanced = errors.New("ledger: entries do not balance")

// Repository persists double-entry ledger data.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// AccountID returns the id of the (kind, owner) account, creating it on first
// use. An empty ownerID resolves to the singleton platform owner.
func (r *Repository) AccountID(ctx context.Context, kind, ownerID string) (string, error) {
	if r.db == nil {
		return "", pkg.ErrNotImplemented
	}
	if ownerID == "" {
		ownerID = platformOwner
	}
	var id string
	err := r.db.QueryRow(ctx,
		`INSERT INTO ledger_accounts (kind, owner_id) VALUES ($1, $2)
		 ON CONFLICT (kind, owner_id) DO UPDATE SET kind = EXCLUDED.kind
		 RETURNING id`,
		kind, ownerID,
	).Scan(&id)
	return id, err
}

// PostTransaction records a balanced set of debit/credit entries atomically.
// The entries must balance (sum(debit) == sum(credit)) and be non-empty.
func (r *Repository) PostTransaction(ctx context.Context, txn *Transaction, entries []Entry) error {
	if r.db == nil {
		return pkg.ErrNotImplemented
	}
	if err := entriesBalanced(entries); err != nil {
		return err
	}
	tx, err := r.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx) //nolint:errcheck // no-op once committed

	var txnID string
	if err := tx.QueryRow(ctx,
		`INSERT INTO transactions (kind, order_id) VALUES ($1, NULLIF($2, '')::uuid) RETURNING id`,
		txn.Kind, txn.OrderID,
	).Scan(&txnID); err != nil {
		return err
	}
	for _, e := range entries {
		if _, err := tx.Exec(ctx,
			`INSERT INTO ledger_entries (txn_id, account_id, debit, credit) VALUES ($1, $2, $3, $4)`,
			txnID, e.AccountID, e.Debit, e.Credit,
		); err != nil {
			return err
		}
	}
	txn.ID = txnID
	return tx.Commit(ctx)
}

// TransactionExists reports whether a transaction of the given kind has already
// been posted for an order. Used to make escrow postings idempotent so a
// replayed payment webhook cannot double-credit.
func (r *Repository) TransactionExists(ctx context.Context, orderID, kind string) (bool, error) {
	if r.db == nil {
		return false, pkg.ErrNotImplemented
	}
	if orderID == "" {
		return false, nil
	}
	var exists bool
	err := r.db.QueryRow(ctx,
		`SELECT EXISTS (SELECT 1 FROM transactions WHERE order_id = $1 AND kind = $2)`,
		orderID, kind,
	).Scan(&exists)
	return exists, err
}

// Balance returns an account's balance as sum(credit) - sum(debit).
func (r *Repository) Balance(ctx context.Context, accountID string) (float64, error) {
	if r.db == nil {
		return 0, pkg.ErrNotImplemented
	}
	var bal float64
	err := r.db.QueryRow(ctx,
		`SELECT COALESCE(SUM(credit - debit), 0) FROM ledger_entries WHERE account_id = $1`,
		accountID,
	).Scan(&bal)
	return bal, err
}

// BalanceByKindOwner returns the balance of the (kind, owner) account, or 0 if
// the account has never been used.
func (r *Repository) BalanceByKindOwner(ctx context.Context, kind, ownerID string) (float64, error) {
	if r.db == nil {
		return 0, pkg.ErrNotImplemented
	}
	if ownerID == "" {
		ownerID = platformOwner
	}
	var bal float64
	err := r.db.QueryRow(ctx,
		`SELECT COALESCE(SUM(e.credit - e.debit), 0)
		   FROM ledger_accounts a LEFT JOIN ledger_entries e ON e.account_id = a.id
		  WHERE a.kind = $1 AND a.owner_id = $2`,
		kind, ownerID,
	).Scan(&bal)
	return bal, err
}

// entriesBalanced validates that entries are non-empty, non-negative, and that
// total debits equal total credits.
func entriesBalanced(entries []Entry) error {
	if len(entries) < 2 {
		return fmt.Errorf("%w: need at least two entries", ErrUnbalanced)
	}
	var debit, credit float64
	for _, e := range entries {
		if e.Debit < 0 || e.Credit < 0 {
			return fmt.Errorf("%w: amounts must be non-negative", ErrUnbalanced)
		}
		debit += e.Debit
		credit += e.Credit
	}
	if math.Abs(debit-credit) > 0.005 {
		return fmt.Errorf("%w: debits %.2f != credits %.2f", ErrUnbalanced, debit, credit)
	}
	if debit == 0 {
		return fmt.Errorf("%w: must move a non-zero amount", ErrUnbalanced)
	}
	return nil
}
