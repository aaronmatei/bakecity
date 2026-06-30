package delivery

import (
	"time"
)

// Delivery lifecycle statuses.
const (
	StatusPending    = "pending"
	StatusDispatched = "dispatched"
	StatusDelivered  = "delivered"
)

// Delivery methods.
const (
	MethodOwn     = "own"     // baker delivers themselves
	MethodCourier = "courier" // third-party courier
	MethodPickup  = "pickup"  // customer collects
	MethodSelf    = "self"    // alias for own/pickup arrangements
)

// validMethods is the set of acceptable delivery methods.
var validMethods = map[string]bool{
	MethodOwn:     true,
	MethodCourier: true,
	MethodPickup:  true,
	MethodSelf:    true,
}

// IsValidMethod reports whether m is an accepted delivery method.
func IsValidMethod(m string) bool {
	return validMethods[m]
}

// Delivery maps to the deliveries table.
type Delivery struct {
	ID           string     `json:"id"`
	OrderID      string     `json:"order_id"`
	Method       string     `json:"method"`
	CourierRef   string     `json:"courier_ref,omitempty"`
	Status       string     `json:"status"`
	ProofMediaID string     `json:"proof_media_id,omitempty"`
	DispatchedAt *time.Time `json:"dispatched_at,omitempty"`
	// ProofSubmittedAt is when the baker submitted proof-of-delivery; the order
	// then awaits the customer's confirmation (or a timed auto-confirm).
	ProofSubmittedAt *time.Time `json:"proof_submitted_at,omitempty"`
	DeliveredAt      *time.Time `json:"delivered_at,omitempty"`
	ConfirmedAt      *time.Time `json:"confirmed_at,omitempty"`
	CreatedAt        time.Time  `json:"created_at"`
}

// DispatchRequest is the payload for dispatching a delivery.
type DispatchRequest struct {
	Method     string `json:"method" binding:"required"`
	CourierRef string `json:"courier_ref"`
}

// ConfirmRequest is the payload for confirming receipt (proof-of-delivery).
type ConfirmRequest struct {
	ProofMediaID string `json:"proof_media_id"`
}
