package analytics

// PlatformStats is an aggregate analytics snapshot.
type PlatformStats struct {
	TotalOrders  int     `json:"total_orders"`
	GMV          float64 `json:"gmv"`
	ActiveBakers int     `json:"active_bakers"`
}
