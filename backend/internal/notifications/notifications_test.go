package notifications

import "testing"

// TestRenderCoversAllTypes ensures every event type renders a non-empty title
// and body (so push/SMS messages are never blank).
func TestRenderCoversAllTypes(t *testing.T) {
	types := []string{
		TypeQuoteProposed, TypeOfferSuggested, TypeQuoteAccepted, TypeDepositConfirmed,
		TypeProductionUpdate,
		TypeOutForDelivery, TypeDelivered, TypeOrderCompleted, TypeReviewRequest,
		TypeDisputeRaised, TypeDisputeResolved, TypePayoutSent,
	}
	for _, ty := range types {
		title, body := render(ty, nil)
		if title == "" || body == "" {
			t.Errorf("render(%q) returned empty title/body (%q/%q)", ty, title, body)
		}
	}
	// Unknown types still get a sane fallback.
	if title, body := render("something_new", nil); title == "" || body == "" {
		t.Errorf("render(unknown) returned empty title/body")
	}
}

// TestMoneyCriticalSet documents which events also go out over SMS.
func TestMoneyCriticalSet(t *testing.T) {
	wantSMS := []string{TypeDepositConfirmed, TypeOrderCompleted, TypePayoutSent}
	for _, ty := range wantSMS {
		if !moneyCritical[ty] {
			t.Errorf("%q should be money-critical (SMS)", ty)
		}
	}
	wantNoSMS := []string{TypeProductionUpdate, TypeQuoteProposed, TypeDelivered}
	for _, ty := range wantNoSMS {
		if moneyCritical[ty] {
			t.Errorf("%q should not be money-critical", ty)
		}
	}
}
