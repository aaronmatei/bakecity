package orders

import "testing"

func TestCancellationSettlement(t *testing.T) {
	const eps = 0.005
	cases := []struct {
		name                              string
		status, role                      string
		deposit                           float64
		wantCust, wantBaker, wantPlatform float64
		wantStatus                        string
	}{
		// Before the deposit is paid: no money has moved.
		{"pre-deposit", StatusApproved, "customer", 10000, 0, 0, 0, StatusCancelled},
		{"deposit-pending", StatusDepositPending, "customer", 10000, 0, 0, 0, StatusCancelled},

		// Deposit paid, before production — customer cancels: refund minus a 10% fee.
		{"deposit-paid customer", StatusDepositPaid, "customer", 10000, 9000, 0, 1000, StatusRefunded},
		// Baker / admin can't-fulfill cancellation: customer made whole.
		{"deposit-paid baker", StatusDepositPaid, "baker", 10000, 10000, 0, 0, StatusRefunded},
		{"deposit-paid admin", StatusDepositPaid, "admin", 10000, 10000, 0, 0, StatusRefunded},

		// In production — customer forfeits 50%; baker keeps it net of 5% commission.
		{"in-production customer", StatusInProduction, "customer", 10000, 5000, 4750, 250, StatusRefunded},
		{"in-production baker", StatusInProduction, "baker", 10000, 10000, 0, 0, StatusRefunded},

		// Later stages: baker/admin full refund.
		{"ready baker", StatusReady, "baker", 8000, 8000, 0, 0, StatusRefunded},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			s := cancellationSettlement(tc.status, tc.role, tc.deposit)
			if abs(s.ToCustomer-tc.wantCust) > eps || abs(s.ToBaker-tc.wantBaker) > eps || abs(s.ToPlatform-tc.wantPlatform) > eps {
				t.Errorf("got (cust %.2f, baker %.2f, platform %.2f), want (%.2f, %.2f, %.2f)",
					s.ToCustomer, s.ToBaker, s.ToPlatform, tc.wantCust, tc.wantBaker, tc.wantPlatform)
			}
			if s.FinalStatus != tc.wantStatus {
				t.Errorf("final status = %s, want %s", s.FinalStatus, tc.wantStatus)
			}
			// Invariant: when funds were held, the legs sum to the deposit.
			if tc.wantStatus == StatusRefunded {
				if abs((s.ToCustomer+s.ToBaker+s.ToPlatform)-tc.deposit) > eps {
					t.Errorf("legs sum %.2f != deposit %.2f", s.ToCustomer+s.ToBaker+s.ToPlatform, tc.deposit)
				}
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
