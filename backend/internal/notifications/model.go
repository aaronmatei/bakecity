package notifications

import (
	"encoding/json"
	"time"
)

// Notification maps to the notifications table.
type Notification struct {
	ID        string          `json:"id"`
	UserID    string          `json:"user_id"`
	Channel   string          `json:"channel"`
	Type      string          `json:"type"`
	Payload   json.RawMessage `json:"payload"`
	ReadAt    *time.Time      `json:"read_at,omitempty"`
	CreatedAt time.Time       `json:"created_at"`
}

// Channel values.
const (
	ChannelPush  = "push"
	ChannelSMS   = "sms"
	ChannelInApp = "in_app"
)
