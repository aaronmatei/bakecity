package admin

import "time"

// BakerSummary is an admin-facing view of a baker profile joined with the
// owner's contact details, used for the approval queue.
type BakerSummary struct {
	ID           string    `json:"id"`
	UserID       string    `json:"user_id"`
	BusinessName string    `json:"business_name"`
	Status       string    `json:"status"`
	KYCStatus    string    `json:"kyc_status"`
	Phone        string    `json:"phone"`
	Email        string    `json:"email,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
}

// ResolveDisputeRequest is the payload for resolving a dispute.
type ResolveDisputeRequest struct {
	Resolution   string  `json:"resolution" binding:"required"`
	RefundAmount float64 `json:"refund_amount"`
}

// RefundRequest is the payload for an admin-initiated order refund.
type RefundRequest struct {
	Amount float64 `json:"amount" binding:"required"`
	Reason string  `json:"reason"`
}
