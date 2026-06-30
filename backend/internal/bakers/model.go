package bakers

import (
	"time"
)

// BakerProfile maps to the baker_profiles table.
type BakerProfile struct {
	ID               string    `json:"id"`
	UserID           string    `json:"user_id"`
	BusinessName     string    `json:"business_name"`
	Bio              string    `json:"bio,omitempty"`
	DeliveryRadiusKM float64   `json:"delivery_radius_km"`
	Status           string    `json:"status"`
	KYCStatus        string    `json:"kyc_status"`
	LeadTimeDays     int       `json:"lead_time_days"`
	DailyCapacity    int       `json:"daily_order_capacity"`
	Lat              *float64  `json:"lat,omitempty"`
	Lng              *float64  `json:"lng,omitempty"`
	// FollowerCount is how many customers have favorited this bakery (set on
	// public profile reads).
	FollowerCount int       `json:"follower_count"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

// BlackoutDate maps to the baker_blackout_dates table.
type BlackoutDate struct {
	ID      string    `json:"id"`
	BakerID string    `json:"baker_id"`
	Date    time.Time `json:"date"`
	Reason  string    `json:"reason,omitempty"`
}

// Baker status values.
const (
	StatusPending   = "pending"
	StatusApproved  = "approved"
	StatusSuspended = "suspended"
)

// KYC status values.
const (
	KYCPending   = "pending"
	KYCSubmitted = "submitted"
	KYCApproved  = "approved"
	KYCRejected  = "rejected"
)

// CreateBakerRequest is the payload for POST /bakers (baker onboarding).
type CreateBakerRequest struct {
	BusinessName     string   `json:"business_name" binding:"required"`
	Bio              string   `json:"bio"`
	DeliveryRadiusKM *float64 `json:"delivery_radius_km"`
	LeadTimeDays     *int     `json:"lead_time_days"`
	DailyCapacity    *int     `json:"daily_order_capacity"`
	Lat              *float64 `json:"lat"`
	Lng              *float64 `json:"lng"`
}

// UpdateBakerRequest is the payload for PATCH /bakers/:id. Nil fields are left
// unchanged.
type UpdateBakerRequest struct {
	BusinessName     *string  `json:"business_name"`
	Bio              *string  `json:"bio"`
	DeliveryRadiusKM *float64 `json:"delivery_radius_km"`
	LeadTimeDays     *int     `json:"lead_time_days"`
	DailyCapacity    *int     `json:"daily_order_capacity"`
	Lat              *float64 `json:"lat"`
	Lng              *float64 `json:"lng"`
}

// AvailabilityRequest is the payload for PUT /bakers/:id/availability. It sets
// scheduling parameters and replaces the blackout-date set.
type AvailabilityRequest struct {
	LeadTimeDays  *int            `json:"lead_time_days"`
	DailyCapacity *int            `json:"daily_order_capacity"`
	BlackoutDates []BlackoutInput `json:"blackout_dates"`
}

// BlackoutInput is a single blackout date in an AvailabilityRequest.
type BlackoutInput struct {
	Date   string `json:"date" binding:"required"` // YYYY-MM-DD
	Reason string `json:"reason"`
}

// Availability is the response for GET /bakers/:id/availability.
type Availability struct {
	BakerID       string         `json:"baker_id"`
	LeadTimeDays  int            `json:"lead_time_days"`
	DailyCapacity int            `json:"daily_order_capacity"`
	BlackoutDates []BlackoutDate `json:"blackout_dates"`
}
