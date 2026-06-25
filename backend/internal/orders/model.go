package orders

import "time"

// Order maps to the orders table.
type Order struct {
	ID               string    `json:"id"`
	CustomerID       string    `json:"customer_id"`
	BakerID          string    `json:"baker_id"`
	ProductID        string    `json:"product_id"`
	Status           string    `json:"status"`
	EventDate        time.Time `json:"event_date"`
	DeliveryAddress  string    `json:"delivery_address"`
	TotalAmount      float64   `json:"total_amount"`
	DepositAmount    float64   `json:"deposit_amount"`
	BalanceAmount    float64   `json:"balance_amount"`
	CommissionAmount float64   `json:"commission_amount"`
	CreatedAt        time.Time `json:"created_at"`
}

// OrderSpec maps to the order_specs table (free-form spec attributes).
type OrderSpec struct {
	ID      string `json:"id"`
	OrderID string `json:"order_id"`
	Key     string `json:"key"`
	Value   string `json:"value"`
}

// CreateOrderRequest is the payload for creating an order.
type CreateOrderRequest struct {
	BakerID         string  `json:"baker_id" binding:"required"`
	ProductID       string  `json:"product_id" binding:"required"`
	EventDate       string  `json:"event_date" binding:"required"`
	DeliveryAddress string  `json:"delivery_address"`
	Lat             float64 `json:"lat"`
	Lng             float64 `json:"lng"`
	Specs           []struct {
		Key   string `json:"key"`
		Value string `json:"value"`
	} `json:"specs"`
}
