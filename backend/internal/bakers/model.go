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
	CreatedAt        time.Time `json:"created_at"`
	UpdatedAt        time.Time `json:"updated_at"`
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
