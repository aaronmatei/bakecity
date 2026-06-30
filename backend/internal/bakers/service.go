package bakers

import (
	"context"
	"net/http"
	"time"

	"github.com/corebalt/bakecity/internal/media"
	"github.com/corebalt/bakecity/pkg"
)

// Actor identifies the authenticated caller for authorization checks.
type Actor struct {
	UserID  string
	IsAdmin bool
}

// Service implements bakers business logic. It uses the media service to store
// and read a baker's KYC identity documents.
type Service struct {
	repo  *Repository
	media *media.Service
}

// NewService constructs a Service.
func NewService(repo *Repository, mediaSvc *media.Service) *Service {
	return &Service{repo: repo, media: mediaSvc}
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

// Get returns a baker profile by id, including its follower count and (if set)
// a presigned storefront cover URL.
func (s *Service) Get(ctx context.Context, id string) (*BakerProfile, error) {
	profile, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if n, err := s.repo.FollowerCount(ctx, id); err == nil {
		profile.FollowerCount = n
	}
	if covers, err := s.media.ListByOwnerKind(ctx, profile.UserID, media.KindBakerCover); err == nil && len(covers) > 0 {
		profile.CoverImageURL = covers[0].URL
	}
	if avatars, err := s.media.ListByOwnerKind(ctx, profile.UserID, media.KindBakerAvatar); err == nil && len(avatars) > 0 {
		profile.AvatarURL = avatars[0].URL
	}
	return profile, nil
}

// GetByUser returns the baker profile owned by the authenticated user.
func (s *Service) GetByUser(ctx context.Context, userID string) (*BakerProfile, error) {
	return s.repo.GetByUserID(ctx, userID)
}

// Update modifies a baker profile; only the owner or an admin may do so.
func (s *Service) Update(ctx context.Context, actor Actor, id string, req UpdateBakerRequest) (*BakerProfile, error) {
	if _, err := s.authorize(ctx, actor, id); err != nil {
		return nil, err
	}
	return s.repo.Update(ctx, id, req)
}

// SubmitKYC marks a profile's KYC as submitted; owner or admin only. At least
// one identity document must have been uploaded first, so a reviewer always has
// something to verify.
func (s *Service) SubmitKYC(ctx context.Context, actor Actor, id string) (*BakerProfile, error) {
	profile, err := s.authorize(ctx, actor, id)
	if err != nil {
		return nil, err
	}
	// A location is required so the bakery is discoverable by distance.
	if profile.Lat == nil || profile.Lng == nil {
		return nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation,
			"set your bakery's location before submitting for review")
	}
	docs, err := s.media.ListByOwnerKind(ctx, profile.UserID, media.KindKYC)
	if err != nil {
		return nil, err
	}
	if len(docs) == 0 {
		return nil, pkg.NewAPIError(http.StatusUnprocessableEntity, pkg.ErrCodeValidation,
			"attach at least one identity document before submitting for review")
	}
	return s.repo.SubmitKYC(ctx, id)
}

// KYCDocs returns the baker's uploaded identity documents (presigned for
// viewing); owner or admin only, so a reviewer can inspect them before
// approving.
func (s *Service) KYCDocs(ctx context.Context, actor Actor, id string) ([]media.Media, error) {
	profile, err := s.authorize(ctx, actor, id)
	if err != nil {
		return nil, err
	}
	return s.media.ListByOwnerKind(ctx, profile.UserID, media.KindKYC)
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
	if _, err := s.authorize(ctx, actor, id); err != nil {
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

// authorize loads the profile and ensures the actor owns it (or is an admin),
// returning the loaded profile so callers can reuse it.
func (s *Service) authorize(ctx context.Context, actor Actor, profileID string) (*BakerProfile, error) {
	profile, err := s.repo.GetByID(ctx, profileID)
	if err != nil {
		return nil, err
	}
	if actor.IsAdmin || profile.UserID == actor.UserID {
		return profile, nil
	}
	return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "not the owner of this baker profile")
}
