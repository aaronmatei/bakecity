// Package pspclient models the licensed Payment Service Provider (e.g.
// Pesapal, Flutterwave, or Safaricom Daraja) that BakeCity integrates with for
// M-Pesa collection, escrow split/release, refunds, and baker payouts.
package pspclient

import (
	"context"
	"encoding/json"

	"github.com/corebalt/bakecity/pkg"
)

// CollectRequest initiates an STK push collection from a customer.
type CollectRequest struct {
	OrderID        string
	Phone          string
	Amount         float64
	Currency       string
	Reference      string
	IdempotencyKey string
}

// CollectResult is returned after initiating a collection.
type CollectResult struct {
	PSPRef string
	Status string
}

// SplitRequest releases escrowed funds, splitting between baker and platform.
type SplitRequest struct {
	OrderID         string
	BakerAmount     float64
	PlatformAmount  float64
	BakerAccountRef string
	IdempotencyKey  string
}

// RefundRequest reverses a previous collection to the customer.
type RefundRequest struct {
	OrderID        string
	PSPRef         string
	Amount         float64
	Reason         string
	IdempotencyKey string
}

// PayoutRequest disburses available funds to a baker.
type PayoutRequest struct {
	BakerID        string
	Phone          string
	Amount         float64
	IdempotencyKey string
}

// OperationResult is a generic PSP operation outcome.
type OperationResult struct {
	PSPRef string
	Status string
}

// WebhookEvent is the normalized result of verifying an inbound PSP callback.
type WebhookEvent struct {
	Type   string
	PSPRef string
	Status string
	Amount float64
}

// PSPClient abstracts the licensed payment provider.
type PSPClient interface {
	// Collect triggers an STK push for the order deposit.
	Collect(ctx context.Context, req CollectRequest) (*CollectResult, error)
	// CollectBalance triggers an STK push for the remaining balance.
	CollectBalance(ctx context.Context, req CollectRequest) (*CollectResult, error)
	// Split releases escrowed funds to baker and platform accounts.
	Split(ctx context.Context, req SplitRequest) (*OperationResult, error)
	// Refund reverses a collection back to the customer.
	Refund(ctx context.Context, req RefundRequest) (*OperationResult, error)
	// Payout disburses available funds to a baker.
	Payout(ctx context.Context, req PayoutRequest) (*OperationResult, error)
	// VerifyWebhook validates an inbound callback signature and normalizes it.
	VerifyWebhook(ctx context.Context, signature string, body []byte) (*WebhookEvent, error)
}

// StubClient is a development PSPClient. It simulates an asynchronous PSP:
// collections return a pending reference (settlement arrives later via a
// webhook), while split/refund/payout resolve synchronously. It performs NO
// real signature verification — VerifyWebhook simply parses a JSON body — and
// must never be used in production.
type StubClient struct{}

// NewStubClient returns a StubClient.
func NewStubClient() *StubClient { return &StubClient{} }

var _ PSPClient = (*StubClient)(nil)

func (s *StubClient) Collect(_ context.Context, req CollectRequest) (*CollectResult, error) {
	return &CollectResult{PSPRef: "stk_" + pkg.GenerateID(), Status: "pending"}, nil
}

func (s *StubClient) CollectBalance(_ context.Context, req CollectRequest) (*CollectResult, error) {
	return &CollectResult{PSPRef: "stk_" + pkg.GenerateID(), Status: "pending"}, nil
}

func (s *StubClient) Split(_ context.Context, req SplitRequest) (*OperationResult, error) {
	return &OperationResult{PSPRef: "split_" + pkg.GenerateID(), Status: "succeeded"}, nil
}

func (s *StubClient) Refund(_ context.Context, req RefundRequest) (*OperationResult, error) {
	return &OperationResult{PSPRef: "refund_" + pkg.GenerateID(), Status: "succeeded"}, nil
}

func (s *StubClient) Payout(_ context.Context, req PayoutRequest) (*OperationResult, error) {
	return &OperationResult{PSPRef: "payout_" + pkg.GenerateID(), Status: "succeeded"}, nil
}

// VerifyWebhook parses a development webhook body of the form
// {"type":"deposit","psp_ref":"...","status":"succeeded","amount":1000}.
// A real implementation would validate the provider's HMAC signature here.
func (s *StubClient) VerifyWebhook(_ context.Context, _ string, body []byte) (*WebhookEvent, error) {
	var ev struct {
		Type   string  `json:"type"`
		PSPRef string  `json:"psp_ref"`
		Status string  `json:"status"`
		Amount float64 `json:"amount"`
	}
	if err := json.Unmarshal(body, &ev); err != nil {
		return nil, err
	}
	return &WebhookEvent{Type: ev.Type, PSPRef: ev.PSPRef, Status: ev.Status, Amount: ev.Amount}, nil
}
