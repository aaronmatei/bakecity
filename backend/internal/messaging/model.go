package messaging

import (
	"time"
)

// Thread maps to the message_threads table.
type Thread struct {
	ID      string `json:"id"`
	OrderID string `json:"order_id"`
}

// Message maps to the messages table.
type Message struct {
	ID        string    `json:"id"`
	ThreadID  string    `json:"thread_id"`
	SenderID  string    `json:"sender_id"`
	Body      string    `json:"body"`
	MediaID   string    `json:"media_id,omitempty"`
	CreatedAt time.Time `json:"created_at"`
}

// SendMessageRequest is the payload for posting a message. Either body or
// media_id must be present (enforced by the service).
type SendMessageRequest struct {
	Body    string `json:"body"`
	MediaID string `json:"media_id"`
}
