package ledger

import "time"

// Ledger account kinds (double-entry escrow accounting).
const (
	AccountCustomer        = "customer"
	AccountBakerPending    = "baker_pending"
	AccountBakerAvailable  = "baker_available"
	AccountPlatformRevenue = "platform_revenue"
	AccountRefunds         = "refunds"
	AccountPayouts         = "payouts" // funds disbursed out to a baker
)

// Transaction kinds.
const (
	TxnDeposit = "deposit"
	TxnBalance = "balance"
	TxnRelease = "release"
	TxnRefund  = "refund"
	TxnPayout  = "payout"
)

// platformOwner is the synthetic owner id for singleton platform accounts
// (platform_revenue, refunds). A concrete value is used rather than NULL so the
// UNIQUE(kind, owner_id) constraint actually dedupes them.
const platformOwner = "00000000-0000-0000-0000-000000000000"

// Account maps to the ledger_accounts table.
type Account struct {
	ID      string `json:"id"`
	Kind    string `json:"kind"`
	OwnerID string `json:"owner_id,omitempty"`
}

// Transaction maps to the transactions table; groups balanced entries.
type Transaction struct {
	ID        string    `json:"id"`
	Kind      string    `json:"kind"`
	OrderID   string    `json:"order_id,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

// Entry maps to the ledger_entries table (one leg of a transaction).
type Entry struct {
	ID        string  `json:"id"`
	TxnID     string  `json:"txn_id"`
	AccountID string  `json:"account_id"`
	Debit     float64 `json:"debit"`
	Credit    float64 `json:"credit"`
}

// Payout maps to the payouts table.
type Payout struct {
	ID        string    `json:"id"`
	BakerID   string    `json:"baker_id"`
	Amount    float64   `json:"amount"`
	PSPRef    string    `json:"psp_ref,omitempty"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}
