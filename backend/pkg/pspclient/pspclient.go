// Package pspclient models the licensed Payment Service Provider (e.g.
// Pesapal, Flutterwave, or Safaricom Daraja) that BakeCity integrates with for
// M-Pesa collection, escrow split/release, refunds, and baker payouts.
package pspclient

import (
	"context"

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

// StubClient is a no-op PSPClient for local development and tests.
type StubClient struct{}

// NewStubClient returns a StubClient.
func NewStubClient() *StubClient { return &StubClient{} }

var _ PSPClient = (*StubClient)(nil)

func (s *StubClient) Collect(context.Context, CollectRequest) (*CollectResult, error) {
	return nil, pkg.ErrNotImplemented
}

func (s *StubClient) CollectBalance(context.Context, CollectRequest) (*CollectResult, error) {
	return nil, pkg.ErrNotImplemented
}

func (s *StubClient) Split(context.Context, SplitRequest) (*OperationResult, error) {
	return nil, pkg.ErrNotImplemented
}

func (s *StubClient) Refund(context.Context, RefundRequest) (*OperationResult, error) {
	return nil, pkg.ErrNotImplemented
}

func (s *StubClient) Payout(context.Context, PayoutRequest) (*OperationResult, error) {
	return nil, pkg.ErrNotImplemented
}

func (s *StubClient) VerifyWebhook(context.Context, string, []byte) (*WebhookEvent, error) {
	return nil, pkg.ErrNotImplemented
}
