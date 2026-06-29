package search

import "time"

// BakerSearchQuery holds discovery parameters for finding bakers. When Lat and
// Lng are set, results are restricted to bakers whose delivery radius covers the
// point and are ordered by distance.
type BakerSearchQuery struct {
	Lat          *float64
	Lng          *float64
	RadiusKM     *float64 // when set (with Lat/Lng), limit to bakers within this distance
	CategorySlug string
	MinPrice     *float64
	MaxPrice     *float64
	MinRating    *float64
	Q            string
	Limit        int
	Offset       int
}

// BakerResult is a baker discovery hit.
type BakerResult struct {
	ID               string   `json:"id"`
	BusinessName     string   `json:"business_name"`
	Bio              string   `json:"bio,omitempty"`
	Status           string   `json:"status"`
	LeadTimeDays     int      `json:"lead_time_days"`
	DeliveryRadiusKM float64  `json:"delivery_radius_km"`
	Lat              *float64 `json:"lat,omitempty"`
	Lng              *float64 `json:"lng,omitempty"`
	AvgRating        float64  `json:"avg_rating"`
	ReviewCount      int      `json:"review_count"`
	DistanceKM       *float64 `json:"distance_km,omitempty"`
}

// ProductSearchQuery holds discovery parameters for finding products. The
// filters compose (all applied with AND). Lat/Lng enable distance for the
// "nearest" sort. Sort is one of: top_rated, best_selling, nearest, price_asc,
// price_desc, newest.
type ProductSearchQuery struct {
	Q            string
	CategorySlug string
	BakerID      string
	Occasion     string   // cakes
	Flavor       string   // cakes
	Format       string   // cakes
	Dietary      []string // must contain all of these
	MinPrice     *float64
	MaxPrice     *float64
	MinRating    *float64
	OnOffer      *bool
	Lat          *float64
	Lng          *float64
	Sort         string
	Limit        int
	Offset       int
}

// ProductResult is a product discovery hit, enriched with baker context and the
// fields the catalog cards and filters need.
type ProductResult struct {
	ID           string    `json:"id"`
	BakerID      string    `json:"baker_id"`
	BakerName    string    `json:"baker_name"`
	CategoryID   string    `json:"category_id,omitempty"`
	Title        string    `json:"title"`
	Description  string    `json:"description,omitempty"`
	BasePrice    float64   `json:"base_price"`
	LeadTimeDays int       `json:"lead_time_days"`
	RatingAvg    float64   `json:"rating_avg"`
	RatingCount  int       `json:"rating_count"`
	IsOnOffer    bool      `json:"is_on_offer"`
	DiscountPct  *int      `json:"discount_pct,omitempty"`
	Dietary      []string  `json:"dietary,omitempty"`
	CakeOccasion string    `json:"cake_occasion,omitempty"`
	CakeFlavor   string    `json:"cake_flavor,omitempty"`
	CakeFormat   string    `json:"cake_format,omitempty"`
	ImageURLs    []string  `json:"image_urls,omitempty"`
	DistanceKM   *float64  `json:"distance_km,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
}
