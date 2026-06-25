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
