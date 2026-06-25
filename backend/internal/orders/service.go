package orders

import (
	"context"
	"math"
	"net/http"
	"time"

	"github.com/corebalt/bakecity/pkg"
)

// Actor identifies the authenticated caller for authorization checks.
type Actor struct {
	UserID  string
	IsAdmin bool
}

// Service implements order business logic, including scheduling guards and the
// state-machine transitions.
type Service struct {
	repo *Repository
	now  func() time.Time
}

// NewService constructs a Service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo, now: time.Now}
}

// Create validates fulfillment and creates an order in QUOTE_REQUESTED.
func (s *Service) Create(ctx context.Context, customerID string, req CreateOrderRequest) (*Order, error) {
	eventDate, err := time.Parse("2006-01-02", req.EventDate)
	if err != nil {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "invalid event_date (want YYYY-MM-DD)")
	}
	if (req.Lat == nil) != (req.Lng == nil) {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "lat and lng must be provided together")
	}

	sched, err := s.repo.BakerScheduling(ctx, req.BakerID)
	if err != nil {
		return nil, err // ErrNotFound -> 404
	}
	if sched.Status != "approved" {
		return nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation, "baker is not accepting orders")
	}
	if err := s.checkFulfillment(ctx, req.BakerID, *sched, eventDate, ""); err != nil {
		return nil, err
	}

	specs := make([]OrderSpec, 0, len(req.Specs))
	for _, in := range req.Specs {
		specs = append(specs, OrderSpec{Key: in.Key, Value: in.Value})
	}
	o := &Order{
		CustomerID:      customerID,
		BakerID:         req.BakerID,
		ProductID:       req.ProductID,
		DeliveryAddress: req.DeliveryAddress,
		Status:          StatusQuoteRequested,
	}
	return s.repo.Create(ctx, o, eventDate, req.Lat, req.Lng, specs)
}

// Get returns an order (with specs) if the actor participates in it.
func (s *Service) Get(ctx context.Context, actor Actor, id string) (*Order, error) {
	o, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if err := s.authorize(ctx, actor, o); err != nil {
		return nil, err
	}
	specs, err := s.repo.GetSpecs(ctx, id)
	if err != nil {
		return nil, err
	}
	o.Specs = specs
	return o, nil
}

// List returns the actor's orders as customer and/or baker.
func (s *Service) List(ctx context.Context, actor Actor, f ListFilter) ([]Order, error) {
	bakerID, err := s.repo.BakerIDForUser(ctx, actor.UserID)
	if err != nil {
		return nil, err
	}
	return s.repo.List(ctx, actor.UserID, bakerID, f)
}

// Cancel moves a pre-COMPLETED order to CANCELLED. Either participant or an
// admin may cancel.
func (s *Service) Cancel(ctx context.Context, actor Actor, id string) (*Order, error) {
	o, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if err := s.authorize(ctx, actor, o); err != nil {
		return nil, err
	}
	if !CanTransition(o.Status, StatusCancelled) {
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "order cannot be cancelled from "+o.Status)
	}
	if err := s.repo.UpdateStatus(ctx, id, StatusCancelled); err != nil {
		return nil, err
	}
	o.Status = StatusCancelled
	return o, nil
}

// checkFulfillment enforces the scheduling guards: lead time, blackout dates,
// and daily capacity. excludeOrderID omits one order from the capacity count
// (used when re-validating an order that already occupies a slot).
func (s *Service) checkFulfillment(ctx context.Context, bakerID string, sched bakerScheduling, eventDate time.Time, excludeOrderID string) error {
	today := s.now().UTC().Truncate(24 * time.Hour)
	earliest := today.AddDate(0, 0, sched.LeadTimeDays)
	if eventDate.Before(earliest) {
		return pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation,
			"event date is sooner than the baker's lead time")
	}
	blackout, err := s.repo.IsBlackout(ctx, bakerID, eventDate)
	if err != nil {
		return err
	}
	if blackout {
		return pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation,
			"baker is unavailable on that date")
	}
	count, err := s.repo.CountOrdersOn(ctx, bakerID, eventDate, excludeOrderID)
	if err != nil {
		return err
	}
	if count >= sched.DailyCapacity {
		return pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation,
			"baker is fully booked on that date")
	}
	return nil
}

// CommissionRate is the platform commission taken on completed orders (5%).
const CommissionRate = 0.05

// OrderByID loads an order without authorization (for use by collaborating
// domains such as quotes, which apply their own checks).
func (s *Service) OrderByID(ctx context.Context, id string) (*Order, error) {
	return s.repo.GetByID(ctx, id)
}

// BakerUserID returns the user id that owns a baker profile.
func (s *Service) BakerUserID(ctx context.Context, bakerID string) (string, error) {
	sched, err := s.repo.BakerScheduling(ctx, bakerID)
	if err != nil {
		return "", err
	}
	return sched.UserID, nil
}

// OnQuoteProposed moves an order into QUOTED when a baker proposes (or revises)
// a quote. Valid from QUOTE_REQUESTED, NEGOTIATING, or QUOTED (idempotent).
func (s *Service) OnQuoteProposed(ctx context.Context, orderID string) error {
	o, err := s.repo.GetByID(ctx, orderID)
	if err != nil {
		return err
	}
	switch o.Status {
	case StatusQuoteRequested, StatusNegotiating, StatusQuoted:
		return s.repo.UpdateStatus(ctx, orderID, StatusQuoted)
	default:
		return pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "cannot quote an order in "+o.Status)
	}
}

// OnQuoteAccepted re-validates fulfillment, records the financial breakdown, and
// transitions the order to APPROVED. depositPct is a percentage (0-100).
func (s *Service) OnQuoteAccepted(ctx context.Context, orderID string, total, depositPct float64) (*Order, error) {
	o, err := s.repo.GetByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if o.Status != StatusQuoted {
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "order is not awaiting acceptance")
	}
	sched, err := s.repo.BakerScheduling(ctx, o.BakerID)
	if err != nil {
		return nil, err
	}
	if o.EventDate != nil {
		if err := s.checkFulfillment(ctx, o.BakerID, *sched, *o.EventDate, o.ID); err != nil {
			return nil, err
		}
	}
	deposit := round2(total * depositPct / 100)
	commission := round2(total * CommissionRate)
	balance := round2(total - deposit)
	if err := s.repo.SetAmountsAndStatus(ctx, orderID, total, deposit, balance, commission, StatusApproved); err != nil {
		return nil, err
	}
	o.TotalAmount, o.DepositAmount, o.BalanceAmount, o.CommissionAmount = total, deposit, balance, commission
	o.Status = StatusApproved
	return o, nil
}

// round2 rounds a monetary value to two decimal places.
func round2(v float64) float64 {
	return math.Round(v*100) / 100
}

// authorize permits the order's customer, its baker, or an admin.
func (s *Service) authorize(ctx context.Context, actor Actor, o *Order) error {
	if actor.IsAdmin || o.CustomerID == actor.UserID {
		return nil
	}
	sched, err := s.repo.BakerScheduling(ctx, o.BakerID)
	if err == nil && sched.UserID == actor.UserID {
		return nil
	}
	return pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "not a participant in this order")
}
