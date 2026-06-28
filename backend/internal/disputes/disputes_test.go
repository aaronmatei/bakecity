package disputes

import (
	"testing"

	"github.com/corebalt/bakecity/internal/orders"
)

func TestSettlement(t *testing.T) {
	const eps = 0.005
	cases := []struct {
		name                                  string
		held, refundReq                       float64
		wantRefund, wantBaker, wantCommission float64
		wantStatus                            string
	}{
		// Baker wins: full deposit released, 5% commission, order completes.
		{"baker wins", 10000, 0, 0, 10000, 500, orders.StatusCompleted},
		// Customer wins: full refund, nothing to baker, order refunded.
		{"full refund", 10000, 10000, 10000, 0, 0, orders.StatusRefunded},
		// Split ruling: partial refund, baker keeps remainder (commission on it).
		{"partial refund", 10000, 4000, 4000, 6000, 300, orders.StatusCompleted},
		// Over-ask is clamped to the held amount (-> full refund).
		{"over-ask clamped", 10000, 99999, 10000, 0, 0, orders.StatusRefunded},
		// Negative is clamped to zero (-> baker wins).
		{"negative clamped", 10000, -50, 0, 10000, 500, orders.StatusCompleted},
		// No escrow held: nothing moves, order completes.
		{"zero held", 0, 0, 0, 0, 0, orders.StatusCompleted},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			refund, baker, commission, status := settlement(tc.held, tc.refundReq)
			if abs(refund-tc.wantRefund) > eps || abs(baker-tc.wantBaker) > eps || abs(commission-tc.wantCommission) > eps {
				t.Errorf("settlement(%.0f, %.0f) = (refund %.2f, baker %.2f, comm %.2f), want (%.2f, %.2f, %.2f)",
					tc.held, tc.refundReq, refund, baker, commission, tc.wantRefund, tc.wantBaker, tc.wantCommission)
			}
			if status != tc.wantStatus {
				t.Errorf("status = %s, want %s", status, tc.wantStatus)
			}
			// Invariant: refund + bakerPortion always equals the held amount.
			if abs((refund+baker)-tc.held) > eps {
				t.Errorf("refund(%.2f) + baker(%.2f) != held(%.2f)", refund, baker, tc.held)
			}
		})
	}
}

func abs(v float64) float64 {
	if v < 0 {
		return -v
	}
	return v
}
