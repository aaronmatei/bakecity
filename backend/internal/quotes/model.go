package quotes

import (
	"time"
)

// Quote maps to the quotes table. A quote is either the baker's priced offer
// (acceptable by the customer) or the customer's suggested offer during
// negotiation, distinguished by ProposedBy.
type Quote struct {
	ID         string     `json:"id"`
	OrderID    string     `json:"order_id"`
	Version     int        `json:"version"`
	Amount      float64    `json:"amount"`
	DepositPct  float64    `json:"deposit_pct"`
	DeliveryFee float64    `json:"delivery_fee"`
	ValidUntil  *time.Time `json:"valid_until,omitempty"`
	Status      string     `json:"status"`
	ProposedBy  string     `json:"proposed_by"`
	IsFinal     bool       `json:"is_final"`
	CreatedAt   time.Time  `json:"created_at"`
}

// Quote status values.
const (
	StatusPending    = "pending"
	StatusAccepted   = "accepted"
	StatusExpired    = "expired"
	StatusRejected   = "rejected"
	StatusSuperseded = "superseded"
)

// Who proposed a quote.
const (
	ProposedByBaker    = "baker"
	ProposedByCustomer = "customer"
)

// CreateQuoteRequest is the payload for a baker proposing a quote.
type CreateQuoteRequest struct {
	Amount      float64 `json:"amount" binding:"required,gt=0"`
	DepositPct  float64 `json:"deposit_pct" binding:"required,gt=0,lte=100"`
	DeliveryFee float64 `json:"delivery_fee" binding:"gte=0"` // courier charge (delivery orders)
	ValidUntil  string  `json:"valid_until"`                  // optional RFC3339 timestamp
	IsFinal     bool    `json:"is_final"`                     // baker's best & final offer
}

// SuggestOfferRequest is the payload for a customer suggesting a price.
type SuggestOfferRequest struct {
	Amount float64 `json:"amount" binding:"required,gt=0"`
}
