package media

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/corebalt/bakecity/internal/orders"
	"github.com/corebalt/bakecity/pkg"
	"github.com/corebalt/bakecity/pkg/storage"
)

// presignTTL is how long an issued upload URL stays valid.
const presignTTL = 15 * time.Minute

// downloadTTL is how long an issued download (view) URL stays valid.
const downloadTTL = 1 * time.Hour

// allowedKinds is the set of acceptable media purposes.
var allowedKinds = map[string]bool{
	KindReference:     true,
	KindProduction:    true,
	KindDeliveryProof: true,
	KindProduct:       true,
}

// Actor identifies the authenticated caller for authorization checks.
type Actor struct {
	UserID  string
	IsAdmin bool
}

// Service implements media business logic: issuing presigned upload URLs and
// tracking the upload lifecycle. Bytes are uploaded by the client directly to
// the object store; the API never proxies them.
type Service struct {
	repo      *Repository
	presigner storage.Presigner
	orders    *orders.Service
}

// NewService constructs a Service.
func NewService(repo *Repository, presigner storage.Presigner, ordersSvc *orders.Service) *Service {
	return &Service{repo: repo, presigner: presigner, orders: ordersSvc}
}

// Presign validates the request, reserves a pending media record owned by the
// caller, and returns a short-lived URL the client uploads the bytes to.
func (s *Service) Presign(ctx context.Context, ownerID string, req PresignRequest) (*PresignResponse, error) {
	kind := strings.ToLower(strings.TrimSpace(req.Kind))
	if !allowedKinds[kind] {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "unknown media kind")
	}
	ct := strings.ToLower(strings.TrimSpace(req.ContentType))
	if !strings.HasPrefix(ct, "image/") && !strings.HasPrefix(ct, "video/") {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "content_type must be an image or video")
	}

	key := kind + "/" + pkg.GenerateID() + extensionFor(ct)
	url, err := s.presigner.PresignUpload(ctx, key, ct, presignTTL)
	if err != nil {
		return nil, err
	}

	m, err := s.repo.Create(ctx, ownerID, req.OrderID, kind, key)
	if err != nil {
		return nil, err
	}
	return &PresignResponse{UploadURL: url, S3Key: m.S3Key, MediaID: m.ID}, nil
}

// Complete marks a media record as uploaded once the client finishes the PUT.
// Only the owner (or an admin) may complete it.
func (s *Service) Complete(ctx context.Context, actor Actor, id string) (*Media, error) {
	m, err := s.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if !actor.IsAdmin && m.OwnerID != actor.UserID {
		return nil, pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "not the owner of this media")
	}
	if m.Status == StatusPending {
		if err := s.repo.SetStatus(ctx, id, StatusUploaded); err != nil {
			return nil, err
		}
		m.Status = StatusUploaded
	}
	return m, nil
}

// ListForOrder returns an order's media (optionally filtered by kind), for a
// participant in that order (the customer or the order's baker, or an admin).
func (s *Service) ListForOrder(ctx context.Context, actor Actor, orderID, kind string) ([]Media, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if err := s.authorizeParticipant(ctx, actor, order); err != nil {
		return nil, err
	}
	items, err := s.repo.ListByOrder(ctx, orderID, strings.ToLower(strings.TrimSpace(kind)))
	if err != nil {
		return nil, err
	}
	for i := range items {
		s.attachURLs(ctx, &items[i])
	}
	return items, nil
}

// attachURLs resolves short-lived presigned download URLs for a media record's
// full image and thumbnail (best-effort; a failure leaves the URL empty).
func (s *Service) attachURLs(ctx context.Context, m *Media) {
	if url, err := s.presigner.PresignDownload(ctx, m.S3Key, downloadTTL); err == nil {
		m.URL = url
	}
	if m.ThumbKey != "" {
		if url, err := s.presigner.PresignDownload(ctx, m.ThumbKey, downloadTTL); err == nil {
			m.ThumbURL = url
		}
	}
}

// authorizeParticipant allows the order's customer, the order's baker, or an
// admin; everyone else is forbidden.
func (s *Service) authorizeParticipant(ctx context.Context, actor Actor, order *orders.Order) error {
	if actor.IsAdmin || order.CustomerID == actor.UserID {
		return nil
	}
	bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID)
	if err == nil && bakerUserID == actor.UserID {
		return nil
	}
	return pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "not a participant in this order")
}

// extensionFor maps a content type to a file extension (empty if unknown).
func extensionFor(contentType string) string {
	switch contentType {
	case "image/jpeg", "image/jpg":
		return ".jpg"
	case "image/png":
		return ".png"
	case "image/webp":
		return ".webp"
	case "image/gif":
		return ".gif"
	case "image/heic":
		return ".heic"
	case "video/mp4":
		return ".mp4"
	case "video/quicktime":
		return ".mov"
	case "video/webm":
		return ".webm"
	default:
		return ""
	}
}
