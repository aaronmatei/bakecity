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

// Notification types (the realtime events from the architecture spec §10).
const (
	TypeQuoteProposed    = "quote_proposed"
	TypeOfferSuggested   = "offer_suggested"
	TypeQuoteAccepted    = "quote_accepted"
	TypeDepositConfirmed = "deposit_confirmed"
	TypeProductionUpdate = "production_update"
	TypeOutForDelivery   = "out_for_delivery"
	TypeDeliveryProof    = "delivery_proof" // baker submitted proof; awaiting customer confirmation
	TypeDelivered        = "delivered"
	TypeOrderCompleted   = "order_completed"
	TypeReviewRequest    = "review_request"
	TypeDisputeRaised    = "dispute_raised"
	TypeDisputeResolved  = "dispute_resolved"
	TypePayoutSent       = "payout_sent"
	TypeOrderCancelled   = "order_cancelled"
)

// moneyCritical types are also pushed over SMS (high-trust in Kenya), per §10:
// deposit confirmed, balance due / order completed, payout sent.
var moneyCritical = map[string]bool{
	TypeDepositConfirmed: true,
	TypeOrderCompleted:   true,
	TypePayoutSent:       true,
}
