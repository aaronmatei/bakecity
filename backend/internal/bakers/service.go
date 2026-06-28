package bakers

import (
	"context"
	"net/http"
	"time"

	"github.com/corebalt/bakecity/pkg"
)

// Actor identifies the authenticated caller for authorization checks.
type Actor struct {
	UserID  string
	IsAdmin bool
}

// Service implements bakers business logic.
type Service struct {
	repo *Repository
}

// NewService constructs a Service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}

// Create registers a new baker profile for the authenticated user.
func (s *Service) Create(ctx context.Context, userID string, req CreateBakerRequest) (*BakerProfile, error) {
	if req.Lat != nil || req.Lng != nil {
		if req.Lat == nil || req.Lng == nil {
			return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "lat and lng must be provided together")
		}
	}
	return s.repo.Create(ctx, userID, req)
}

// Get returns a baker profile by id.
func (s *Service) Get(ctx context.Context, id string) (*BakerProfile, error) {
	return s.repo.GetByID(ctx, id)
}

// GetByUser returns the baker profile owned by the authenticated user.
func (s *Service) GetByUser(ctx context.Context, userID string) (*BakerProfile, error) {
	return s.repo.GetByUserID(ctx, userID)
}

// Update modifies a baker profile; only the owner or an admin may do so.
func (s *Service) Update(ctx context.Context, actor Actor, id string, req UpdateBakerRequest) (*BakerProfile, error) {
	if err := s.authorize(ctx, actor, id); err != nil {
		return nil, err
	}
	return s.repo.Update(ctx, id, req)
}

// SubmitKYC marks a profile's KYC as submitted; owner or admin only.
func (s *Service) SubmitKYC(ctx context.Context, actor Actor, id string) (*BakerProfile, error) {
	if err := s.authorize(ctx, actor, id); err != nil {
		return nil, err
	}
	return s.repo.SubmitKYC(ctx, id)
}

// GetAvailability returns the baker's scheduling parameters and blackout dates.
func (s *Service) GetAvailability(ctx context.Context, id string) (*Availability, error) {
	profile, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	dates, err := s.repo.ListBlackoutDates(ctx, id)
	if err != nil {
		return nil, err
	}
	return &Availability{
		BakerID:       profile.ID,
		LeadTimeDays:  profile.LeadTimeDays,
		DailyCapacity: profile.DailyCapacity,
		BlackoutDates: dates,
	}, nil
}

// SetAvailability updates scheduling parameters and replaces blackout dates;
// owner or admin only.
func (s *Service) SetAvailability(ctx context.Context, actor Actor, id string, req AvailabilityRequest) (*Availability, error) {
	if err := s.authorize(ctx, actor, id); err != nil {
		return nil, err
	}
	parsed := make([]parsedBlackout, 0, len(req.BlackoutDates))
	for _, d := range req.BlackoutDates {
		day, err := time.Parse("2006-01-02", d.Date)
		if err != nil {
			return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "invalid blackout date: "+d.Date)
		}
		parsed = append(parsed, parsedBlackout{Date: day, Reason: d.Reason})
	}
	if err := s.repo.SetAvailability(ctx, id, req.LeadTimeDays, req.DailyCapacity, parsed); err != nil {
		return nil, err
	}
	return s.GetAvailability(ctx, id)
}

// authorize loads the profile and ensures the actor owns it (or is an admin).
func (s *Service) authorize(ctx context.Context, actor Actor, profileID string) error {
	profile, err := s.repo.GetByID(ctx, profileID)
	if err != nil {
		return err
	}
	if actor.IsAdmin || profile.UserID == actor.UserID {
		return nil
	}
	return pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "not the owner of this baker profile")
}
