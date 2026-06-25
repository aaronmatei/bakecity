package quotes

import (
	"time"
)

// Quote maps to the quotes table.
type Quote struct {
	ID         string    `json:"id"`
	OrderID    string    `json:"order_id"`
	Version    int       `json:"version"`
	Amount     float64   `json:"amount"`
	DepositPct float64   `json:"deposit_pct"`
	ValidUntil time.Time `json:"valid_until"`
	Status     string    `json:"status"`
	CreatedAt  time.Time `json:"created_at"`
}

// Quote status values.
const (
	StatusPending  = "pending"
	StatusAccepted = "accepted"
	StatusExpired  = "expired"
	StatusRejected = "rejected"
)

// CreateQuoteRequest is the payload for creating a quote.
type CreateQuoteRequest struct {
	Amount     float64 `json:"amount" binding:"required"`
	DepositPct float64 `json:"deposit_pct" binding:"required"`
	ValidUntil string  `json:"valid_until"`
}
