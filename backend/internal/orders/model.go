package orders

import "time"

// Order maps to the orders table.
type Order struct {
	ID               string      `json:"id"`
	OrderNumber      int64       `json:"order_number"`
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
	// FulfillmentType is "delivery" (courier) or "pickup" (customer collects).
	FulfillmentType string  `json:"fulfillment_type"`
	DeliveryFee     float64 `json:"delivery_fee"`
	// Counterparty display names (populated on list/detail reads): the customer's
	// personal name and the bakery's business name.
	CustomerName string      `json:"customer_name,omitempty"`
	BakerName    string      `json:"baker_name,omitempty"`
	CreatedAt    time.Time   `json:"created_at"`
	Specs        []OrderSpec `json:"specs,omitempty"`
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
	Fulfillment     string      `json:"fulfillment"` // "delivery" (default) or "pickup"
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

// ProductPerf is one product's sales performance for a baker.
type ProductPerf struct {
	ProductID  string  `json:"product_id"`
	Title      string  `json:"title"`
	OrderCount int     `json:"order_count"`
	Revenue    float64 `json:"revenue"`
}

// TrendPoint is net revenue for one calendar month (period = "YYYY-MM").
type TrendPoint struct {
	Period  string  `json:"period"`
	Revenue float64 `json:"revenue"`
}

// BakerInsights summarizes a baker's order book: counts by status, completed
// revenue (gross and net of commission), the top products, and a monthly net
// revenue trend.
type BakerInsights struct {
	StatusCounts    map[string]int `json:"status_counts"`
	CompletedOrders int            `json:"completed_orders"`
	GrossRevenue    float64        `json:"gross_revenue"`
	NetRevenue      float64        `json:"net_revenue"`
	FollowerCount   int            `json:"follower_count"`
	TopProducts     []ProductPerf  `json:"top_products"`
	RevenueTrend    []TrendPoint   `json:"revenue_trend"`
}

// bakerScheduling holds the fields needed to validate fulfillment of an order.
type bakerScheduling struct {
	UserID        string
	Status        string
	LeadTimeDays  int
	DailyCapacity int
}
