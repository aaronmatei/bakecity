package users

import (
	"time"
)

// User maps to the users table.
type User struct {
	ID            string    `json:"id"`
	RoleMask      int       `json:"role_mask"`
	Phone         string    `json:"phone"`
	Email         string    `json:"email,omitempty"`
	PhoneVerified bool      `json:"phone_verified"`
	CreatedAt     time.Time `json:"created_at"`
	UpdatedAt     time.Time `json:"updated_at"`
}

// UpdateMeRequest is the payload for PATCH /me.
type UpdateMeRequest struct {
	Email string `json:"email"`
	Phone string `json:"phone"`
}
