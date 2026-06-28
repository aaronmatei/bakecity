package payments

import "time"

// Payment kinds.
const (
	KindDeposit = "deposit"
	KindBalance = "balance"
	KindRefund  = "refund"
)

// Payment status values.
const (
	StatusPending   = "pending"
	StatusSucceeded = "succeeded"
	StatusFailed    = "failed"
)

// Payment maps to the payments table.
type Payment struct {
	ID             string    `json:"id"`
	OrderID        string    `json:"order_id"`
	Kind           string    `json:"kind"`
	PSPRef         string    `json:"psp_ref,omitempty"`
	Amount         float64   `json:"amount"`
	Status         string    `json:"status"`
	IdempotencyKey string    `json:"-"`
	CreatedAt      time.Time `json:"created_at"`
}

// CollectRequest is the payload for initiating a deposit/balance collection.
type CollectRequest struct {
	Phone string `json:"phone" binding:"required"`
}

// Payout status values (maps to the payouts table).
const (
	PayoutPending = "pending"
	PayoutPaid    = "paid"
	PayoutFailed  = "failed"
)

// Payout maps to the payouts table — a disbursement of a baker's available
// balance out to their M-Pesa.
type Payout struct {
	ID        string    `json:"id"`
	BakerID   string    `json:"baker_id"`
	Amount    float64   `json:"amount"`
	PSPRef    string    `json:"psp_ref,omitempty"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

// BalanceSummary reports a baker's ledger position for the payout screen.
type BalanceSummary struct {
	Available float64 `json:"available"` // released funds awaiting payout
	Pending   float64 `json:"pending"`   // escrow held for in-flight orders
	PaidOut   float64 `json:"paid_out"`  // total disbursed to date
}
