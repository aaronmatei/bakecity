package ledger

import (
	"context"
	"errors"
	"math"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// TestEntriesBalanced covers the balancing rule without touching a database.
func TestEntriesBalanced(t *testing.T) {
	cases := []struct {
		name    string
		entries []Entry
		wantErr bool
	}{
		{"balanced two-leg", []Entry{{Debit: 100}, {Credit: 100}}, false},
		{"balanced three-leg split", []Entry{{Debit: 100}, {Credit: 95}, {Credit: 5}}, false},
		{"unbalanced", []Entry{{Debit: 100}, {Credit: 50}}, true},
		{"single entry", []Entry{{Debit: 100}}, true},
		{"negative amount", []Entry{{Debit: -100}, {Credit: -100}}, true},
		{"zero movement", []Entry{{Debit: 0}, {Credit: 0}}, true},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			err := entriesBalanced(tc.entries)
			if tc.wantErr && !errors.Is(err, ErrUnbalanced) {
				t.Fatalf("want ErrUnbalanced, got %v", err)
			}
			if !tc.wantErr && err != nil {
				t.Fatalf("want nil, got %v", err)
			}
		})
	}
}

// TestEscrowFlow exercises the full escrow lifecycle against a real database.
func TestEscrowFlow(t *testing.T) {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		t.Skip("DATABASE_URL not set; skipping ledger integration test")
	}
	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("connect: %v", err)
	}
	defer pool.Close()

	svc := NewService(NewRepository(pool))
	customer := pkg.GenerateID()
	baker := pkg.GenerateID()

	approx := func(name string, got, want float64) {
		t.Helper()
		if math.Abs(got-want) > 0.005 {
			t.Fatalf("%s = %.2f, want %.2f", name, got, want)
		}
	}
	custBal := func() float64 {
		b, err := svc.repo.BalanceByKindOwner(ctx, AccountCustomer, customer)
		if err != nil {
			t.Fatalf("customer balance: %v", err)
		}
		return b
	}

	// Deposit 10,000 held in escrow.
	if err := svc.RecordDeposit(ctx, "", customer, baker, 10000); err != nil {
		t.Fatalf("deposit: %v", err)
	}
	pend, _ := svc.BakerPendingBalance(ctx, baker)
	approx("pending after deposit", pend, 10000)
	approx("customer after deposit", custBal(), -10000)

	// Balance 10,000 paid; release 20,000 total with 1,000 commission.
	revBefore, _ := svc.PlatformRevenue(ctx)
	if err := svc.RecordBalanceAndRelease(ctx, "", customer, baker, 10000, 20000, 1000); err != nil {
		t.Fatalf("release: %v", err)
	}
	pend, _ = svc.BakerPendingBalance(ctx, baker)
	avail, _ := svc.BakerAvailableBalance(ctx, baker)
	revAfter, _ := svc.PlatformRevenue(ctx)
	approx("pending after release", pend, 0)
	approx("available after release", avail, 19000)
	approx("commission delta", revAfter-revBefore, 1000)
	approx("customer after release", custBal(), -20000)

	// Refund flow on a separate pair.
	c2, b2 := pkg.GenerateID(), pkg.GenerateID()
	if err := svc.RecordDeposit(ctx, "", c2, b2, 5000); err != nil {
		t.Fatalf("deposit2: %v", err)
	}
	if err := svc.RecordRefund(ctx, "", c2, b2, 2000); err != nil {
		t.Fatalf("refund: %v", err)
	}
	pend2, _ := svc.BakerPendingBalance(ctx, b2)
	approx("pending after refund", pend2, 3000)

	// Global double-entry invariant: every entry nets to zero.
	var total float64
	if err := pool.QueryRow(ctx, `SELECT COALESCE(SUM(credit - debit), 0) FROM ledger_entries`).Scan(&total); err != nil {
		t.Fatalf("global sum: %v", err)
	}
	approx("global ledger sum", total, 0)
}
