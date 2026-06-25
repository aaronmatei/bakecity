package orders

import "time"

// Order maps to the orders table.
type Order struct {
	ID               string      `json:"id"`
	CustomerID       string      `json:"customer_id"`
	BakerID          string      `json:"baker_id"`
	ProductID        string      `json:"product_id,omitempty"`
	Status           string      `json:"status"`
	EventDate        *time.Time  `json:"event_date,omitempty"`
	DeliveryAddress  string      `json:"delivery_address,omitempty"`
	TotalAmount      float64     `json:"total_amount"`
	DepositAmount    float64     `json:"deposit_amount"`
	BalanceAmount    float64     `json:"balance_amount"`
	CommissionAmount float64     `json:"commission_amount"`
	CreatedAt        time.Time   `json:"created_at"`
	Specs            []OrderSpec `json:"specs,omitempty"`
}

// OrderSpec maps to the order_specs table (free-form spec attributes).
type OrderSpec struct {
	ID      string `json:"id,omitempty"`
	OrderID string `json:"order_id,omitempty"`
	Key     string `json:"key"`
	Value   string `json:"value"`
}

// CreateOrderRequest is the payload for creating an order.
type CreateOrderRequest struct {
	BakerID         string      `json:"baker_id" binding:"required"`
	ProductID       string      `json:"product_id"`
	EventDate       string      `json:"event_date" binding:"required"` // YYYY-MM-DD
	DeliveryAddress string      `json:"delivery_address"`
	Lat             *float64    `json:"lat"`
	Lng             *float64    `json:"lng"`
	Specs           []SpecInput `json:"specs"`
}

// SpecInput is a single order spec attribute in a CreateOrderRequest.
type SpecInput struct {
	Key   string `json:"key" binding:"required"`
	Value string `json:"value"`
}

// CancelRequest is the payload for cancelling an order.
type CancelRequest struct {
	Reason string `json:"reason"`
}

// ListFilter narrows an order listing for the authenticated user.
type ListFilter struct {
	Role   string // "customer" (default), "baker", or "all"
	Status string
	Limit  int
	Offset int
}

// bakerScheduling holds the fields needed to validate fulfillment of an order.
type bakerScheduling struct {
	UserID        string
	Status        string
	LeadTimeDays  int
	DailyCapacity int
}
