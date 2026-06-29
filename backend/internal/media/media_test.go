package media

import (
	"context"
	"errors"
	"net/http"
	"testing"

	"github.com/corebalt/bakecity/pkg"
	"github.com/corebalt/bakecity/pkg/storage"
)

func TestExtensionFor(t *testing.T) {
	cases := map[string]string{
		"image/jpeg":      ".jpg",
		"image/png":       ".png",
		"image/webp":      ".webp",
		"video/mp4":       ".mp4",
		"video/quicktime": ".mov",
		"application/pdf": "", // unknown -> no extension
	}
	for ct, want := range cases {
		if got := extensionFor(ct); got != want {
			t.Errorf("extensionFor(%q) = %q, want %q", ct, got, want)
		}
	}
}

// TestPresignValidation covers the request-validation branches that reject
// before any database access (so a nil-db repository is never reached).
func TestPresignValidation(t *testing.T) {
	svc := NewService(NewRepository(nil), storage.NewStubPresigner("b", "r"), nil)
	ctx := context.Background()

	cases := []struct {
		name string
		req  PresignRequest
	}{
		{"unknown kind", PresignRequest{Kind: "bogus", ContentType: "image/png"}},
		{"non-media content type", PresignRequest{Kind: KindProduction, ContentType: "application/pdf"}},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			_, err := svc.Presign(ctx, "owner", tc.req)
			var apiErr *pkg.APIError
			if !errors.As(err, &apiErr) || apiErr.Status != http.StatusBadRequest {
				t.Fatalf("want 400 APIError, got %v", err)
			}
		})
	}
}
