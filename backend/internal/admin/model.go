package admin

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
