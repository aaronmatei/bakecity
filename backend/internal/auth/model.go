package auth

import "time"

// RegisterRequest is the payload for user registration.
type RegisterRequest struct {
	Phone    string `json:"phone" binding:"required"`
	Email    string `json:"email"`
	Password string `json:"password" binding:"required,min=8"`
	Role     string `json:"role"` // customer | baker
}

// LoginRequest is the payload for user login.
type LoginRequest struct {
	Identifier string `json:"identifier" binding:"required"` // phone or email
	Password   string `json:"password" binding:"required"`
}

// AuthResponse is returned on successful register/login.
type AuthResponse struct {
	UserID    string    `json:"user_id"`
	Token     string    `json:"token"`
	RoleMask  int       `json:"role_mask"`
	ExpiresAt time.Time `json:"expires_at"`
}

// Credential is the stored authentication record for a user.
type Credential struct {
	UserID       string
	PasswordHash string
	RoleMask     int
}
