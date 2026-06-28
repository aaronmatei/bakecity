package analytics

// PlatformStats is an aggregate analytics snapshot for the ops dashboard.
type PlatformStats struct {
	TotalOrders     int     `json:"total_orders"`
	CompletedOrders int     `json:"completed_orders"`
	GMV             float64 `json:"gmv"`              // gross merchandise value of completed orders
	PlatformRevenue float64 `json:"platform_revenue"` // commission realized on completed orders
	ActiveBakers    int     `json:"active_bakers"`    // approved baker profiles
	OpenDisputes    int     `json:"open_disputes"`
}
