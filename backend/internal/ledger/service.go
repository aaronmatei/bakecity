package ledger

import (
	"context"
)

// Service implements ledger business logic. It is an internal accounting module
// used by payments/disputes/admin rather than a public HTTP surface.
//
// Convention: balances are sum(credit) - sum(debit). A customer who has paid in
// carries a negative balance; baker_available and platform_revenue carry
// positive balances representing money owed out.
type Service struct {
	repo *Repository
}

// NewService constructs a Service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// RecordDeposit books a held deposit: customer pays in, funds sit in the baker's
// pending (escrow) account. Idempotent per order: a deposit already booked for
// the order is a no-op.
func (s *Service) RecordDeposit(ctx context.Context, orderID, customerID, bakerID string, amount float64) error {
	if done, err := s.repo.TransactionExists(ctx, orderID, TxnDeposit); err != nil || done {
		return err
	}
	cust, pend, err := s.customerAndPending(ctx, customerID, bakerID)
	if err != nil {
		return err
	}
	return s.repo.PostTransaction(ctx, &Transaction{Kind: TxnDeposit, OrderID: orderID}, []Entry{
		{AccountID: cust, Debit: amount},
		{AccountID: pend, Credit: amount},
	})
}

// RecordBalanceAndRelease books the balance payment and the escrow release:
// pending funds split into the baker's available balance (net) and the
// platform's revenue (commission).
func (s *Service) RecordBalanceAndRelease(ctx context.Context, orderID, customerID, bakerID string, balanceAmount, total, commission float64) error {
	if done, err := s.repo.TransactionExists(ctx, orderID, TxnRelease); err != nil || done {
		return err
	}
	cust, pend, err := s.customerAndPending(ctx, customerID, bakerID)
	if err != nil {
		return err
	}
	if balanceAmount > 0 {
		balanceDone, err := s.repo.TransactionExists(ctx, orderID, TxnBalance)
		if err != nil {
			return err
		}
		if !balanceDone {
			if err := s.repo.PostTransaction(ctx, &Transaction{Kind: TxnBalance, OrderID: orderID}, []Entry{
				{AccountID: cust, Debit: balanceAmount},
				{AccountID: pend, Credit: balanceAmount},
			}); err != nil {
				return err
			}
		}
	}
	avail, err := s.repo.AccountID(ctx, AccountBakerAvailable, bakerID)
	if err != nil {
		return err
	}
	rev, err := s.repo.AccountID(ctx, AccountPlatformRevenue, "")
	if err != nil {
		return err
	}
	return s.repo.PostTransaction(ctx, &Transaction{Kind: TxnRelease, OrderID: orderID}, []Entry{
		{AccountID: pend, Debit: total},
		{AccountID: avail, Credit: total - commission},
		{AccountID: rev, Credit: commission},
	})
}

// RecordRefund returns held funds from the baker's pending account back to the
// customer. Idempotent per order (a refund already booked for the order is a
// no-op); orders without an id (e.g. tests) are not deduped.
func (s *Service) RecordRefund(ctx context.Context, orderID, customerID, bakerID string, amount float64) error {
	if done, err := s.repo.TransactionExists(ctx, orderID, TxnRefund); err != nil || done {
		return err
	}
	cust, pend, err := s.customerAndPending(ctx, customerID, bakerID)
	if err != nil {
		return err
	}
	return s.repo.PostTransaction(ctx, &Transaction{Kind: TxnRefund, OrderID: orderID}, []Entry{
		{AccountID: pend, Debit: amount},
		{AccountID: cust, Credit: amount},
	})
}

// SettleDispute books the resolution of a disputed order's escrow: refundAmount
// returns to the customer, and bakerPortion releases to the baker net of
// commission (commission to the platform). Either leg may be zero. Idempotent
// per order via the TxnRefund / TxnRelease guards.
func (s *Service) SettleDispute(ctx context.Context, orderID, customerID, bakerID string, refundAmount, bakerPortion, commission float64) error {
	cust, pend, err := s.customerAndPending(ctx, customerID, bakerID)
	if err != nil {
		return err
	}
	if refundAmount > 0 {
		done, err := s.repo.TransactionExists(ctx, orderID, TxnRefund)
		if err != nil {
			return err
		}
		if !done {
			if err := s.repo.PostTransaction(ctx, &Transaction{Kind: TxnRefund, OrderID: orderID}, []Entry{
				{AccountID: pend, Debit: refundAmount},
				{AccountID: cust, Credit: refundAmount},
			}); err != nil {
				return err
			}
		}
	}
	if bakerPortion > 0 {
		done, err := s.repo.TransactionExists(ctx, orderID, TxnRelease)
		if err != nil {
			return err
		}
		if !done {
			avail, err := s.repo.AccountID(ctx, AccountBakerAvailable, bakerID)
			if err != nil {
				return err
			}
			rev, err := s.repo.AccountID(ctx, AccountPlatformRevenue, "")
			if err != nil {
				return err
			}
			if err := s.repo.PostTransaction(ctx, &Transaction{Kind: TxnRelease, OrderID: orderID}, []Entry{
				{AccountID: pend, Debit: bakerPortion},
				{AccountID: avail, Credit: bakerPortion - commission},
				{AccountID: rev, Credit: commission},
			}); err != nil {
				return err
			}
		}
	}
	return nil
}

// BakerAvailableBalance is the amount a baker can be paid out.
func (s *Service) BakerAvailableBalance(ctx context.Context, bakerID string) (float64, error) {
	return s.repo.BalanceByKindOwner(ctx, AccountBakerAvailable, bakerID)
}

// BakerPendingBalance is the amount currently held in escrow for a baker.
func (s *Service) BakerPendingBalance(ctx context.Context, bakerID string) (float64, error) {
	return s.repo.BalanceByKindOwner(ctx, AccountBakerPending, bakerID)
}

// PlatformRevenue is the total commission realized.
func (s *Service) PlatformRevenue(ctx context.Context) (float64, error) {
	return s.repo.BalanceByKindOwner(ctx, AccountPlatformRevenue, "")
}

// customerAndPending resolves the customer and baker-pending account ids.
func (s *Service) customerAndPending(ctx context.Context, customerID, bakerID string) (string, string, error) {
	cust, err := s.repo.AccountID(ctx, AccountCustomer, customerID)
	if err != nil {
		return "", "", err
	}
	pend, err := s.repo.AccountID(ctx, AccountBakerPending, bakerID)
	if err != nil {
		return "", "", err
	}
	return cust, pend, nil
}
