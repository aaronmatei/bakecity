package disputes

import (
	"time"
)

// Dispute maps to the disputes table.
type Dispute struct {
	ID           string     `json:"id"`
	OrderID      string     `json:"order_id"`
	RaisedBy     string     `json:"raised_by"`
	Reason       string     `json:"reason"`
	Status       string     `json:"status"`
	Resolution   string     `json:"resolution,omitempty"`
	RefundAmount float64    `json:"refund_amount,omitempty"`
	ResolvedBy   string     `json:"resolved_by,omitempty"`
	ResolvedAt   *time.Time `json:"resolved_at,omitempty"`
	CreatedAt    time.Time  `json:"created_at"`
}

// Dispute status values.
const (
	StatusOpen     = "open"
	StatusResolved = "resolved"
	StatusRejected = "rejected"
)

// CreateDisputeRequest is the payload for raising a dispute.
type CreateDisputeRequest struct {
	Reason string `json:"reason" binding:"required"`
}
