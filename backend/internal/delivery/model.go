package delivery

import (
	"time"
)

// Delivery maps to the deliveries table.
type Delivery struct {
	ID           string     `json:"id"`
	OrderID      string     `json:"order_id"`
	Method       string     `json:"method"`
	CourierRef   string     `json:"courier_ref,omitempty"`
	Status       string     `json:"status"`
	ProofMediaID string     `json:"proof_media_id,omitempty"`
	DispatchedAt *time.Time `json:"dispatched_at,omitempty"`
	DeliveredAt  *time.Time `json:"delivered_at,omitempty"`
	ConfirmedAt  *time.Time `json:"confirmed_at,omitempty"`
}

// DispatchRequest is the payload for dispatching a delivery.
type DispatchRequest struct {
	Method     string `json:"method" binding:"required"`
	CourierRef string `json:"courier_ref"`
}

// ConfirmRequest is the payload for confirming receipt.
type ConfirmRequest struct {
	ProofMediaID string `json:"proof_media_id"`
}
