package notifications

import (
	"context"
	"log"
)

// Sender delivers a notification over an out-of-band transport (push / SMS).
// The in-app copy is always persisted by the Service; Sender handles the
// push and SMS fan-out described in the architecture spec §10.
type Sender interface {
	// Push delivers a notification to a user's devices (e.g. FCM).
	Push(ctx context.Context, userID, title, body string) error
	// SMS delivers a transactional SMS to a phone number (e.g. Africa's Talking).
	SMS(ctx context.Context, phone, body string) error
}

// StubSender is a development Sender. It logs instead of calling FCM / Africa's
// Talking, so the notification fan-out is exercisable without those providers
// configured. Swap in a real implementation for production.
type StubSender struct{}

// NewStubSender returns a StubSender.
func NewStubSender() *StubSender { return &StubSender{} }

var _ Sender = (*StubSender)(nil)

// Push logs a would-be push notification.
func (s *StubSender) Push(_ context.Context, userID, title, _ string) error {
	log.Printf("notify[push]: user=%s %q", userID, title)
	return nil
}

// SMS logs a would-be transactional SMS.
func (s *StubSender) SMS(_ context.Context, phone, body string) error {
	log.Printf("notify[sms]: phone=%s %q", phone, body)
	return nil
}
