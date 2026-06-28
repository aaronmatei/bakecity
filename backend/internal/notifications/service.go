package notifications

import (
	"context"
	"encoding/json"
	"log"
)

// Broadcaster delivers a raw message to a user's live connections (WebSocket).
type Broadcaster interface {
	Broadcast(ctx context.Context, userID string, message []byte)
}

// Service implements notifications business logic: persisting an in-app feed and
// fanning out realtime (WebSocket), push, and SMS deliveries for domain events.
type Service struct {
	repo   *Repository
	sender Sender
	hub    Broadcaster
}

// NewService constructs a Service. hub may be nil (no realtime transport).
func NewService(repo *Repository, sender Sender, hub Broadcaster) *Service {
	return &Service{repo: repo, sender: sender, hub: hub}
}

// Notify records an in-app notification for a user and best-effort dispatches it
// over push (and SMS for money-critical events). It is fire-and-forget: any
// delivery failure is logged, never returned, so a notification can never break
// the business operation that triggered it.
func (s *Service) Notify(ctx context.Context, userID, notifType string, payload map[string]any) {
	if s == nil || userID == "" {
		return
	}
	data, err := json.Marshal(payload)
	if err != nil {
		data = []byte("{}")
	}
	n, err := s.repo.Create(ctx, userID, ChannelInApp, notifType, data)
	if err != nil {
		log.Printf("notify: persist %s for %s failed: %v", notifType, userID, err)
		// Still broadcast a transient copy so a live client isn't starved.
		n = &Notification{UserID: userID, Channel: ChannelInApp, Type: notifType, Payload: data}
	}

	// Realtime: push the notification to the user's open WebSocket connections.
	if s.hub != nil {
		if msg, mErr := json.Marshal(n); mErr == nil {
			s.hub.Broadcast(ctx, userID, msg)
		}
	}

	title, body := render(notifType, payload)
	if err := s.sender.Push(ctx, userID, title, body); err != nil {
		log.Printf("notify: push %s for %s failed: %v", notifType, userID, err)
	}
	if moneyCritical[notifType] {
		if phone, err := s.repo.UserPhone(ctx, userID); err == nil && phone != "" {
			if err := s.sender.SMS(ctx, phone, body); err != nil {
				log.Printf("notify: sms %s for %s failed: %v", notifType, userID, err)
			}
		}
	}
}

// List returns a user's notifications (optionally unread only), newest first.
func (s *Service) List(ctx context.Context, userID string, unreadOnly bool, limit, offset int) ([]Notification, error) {
	return s.repo.ListByUser(ctx, userID, unreadOnly, limit, offset)
}

// MarkRead marks one of the user's notifications read.
func (s *Service) MarkRead(ctx context.Context, userID, id string) error {
	return s.repo.MarkRead(ctx, id, userID)
}

// MarkAllRead marks all of a user's notifications read, returning the count.
func (s *Service) MarkAllRead(ctx context.Context, userID string) (int64, error) {
	return s.repo.MarkAllRead(ctx, userID)
}

// UnreadCount returns the user's unread notification count.
func (s *Service) UnreadCount(ctx context.Context, userID string) (int, error) {
	return s.repo.UnreadCount(ctx, userID)
}

// render produces a human-readable title and body for an event type. The body
// is what gets pushed / texted; the structured payload travels in-app.
func render(notifType string, _ map[string]any) (title, body string) {
	switch notifType {
	case TypeQuoteProposed:
		return "Quote ready", "A baker has sent you a quote for your order."
	case TypeQuoteAccepted:
		return "Quote accepted", "Your quote was accepted — you can start once the deposit is paid."
	case TypeDepositConfirmed:
		return "Deposit confirmed", "Your deposit was received and your order is now in the queue."
	case TypeProductionUpdate:
		return "Production update", "There's a new update on your order's progress."
	case TypeOutForDelivery:
		return "Out for delivery", "Your order is on its way."
	case TypeDelivered:
		return "Delivered", "Your order has been delivered."
	case TypeOrderCompleted:
		return "Order completed", "Your order is complete. Thanks for using BakeCity!"
	case TypeReviewRequest:
		return "How did it go?", "Leave a review for your completed order."
	case TypeDisputeRaised:
		return "Dispute opened", "A dispute was opened on an order. Our team will review it."
	case TypeDisputeResolved:
		return "Dispute resolved", "A dispute on your order has been resolved."
	case TypePayoutSent:
		return "Payout sent", "Your available balance has been paid out."
	case TypeOrderCancelled:
		return "Order cancelled", "An order was cancelled; any refund due has been processed."
	default:
		return "Notification", "You have a new notification."
	}
}
