// Package storage models the object store (S3 or a compatible service) that
// BakeCity uses for media. Clients upload bytes directly via a short-lived
// presigned URL; the API never proxies the upload itself.
package storage

import (
	"context"
	"fmt"
	"strings"
	"time"
)

// Presigner issues short-lived URLs for direct-to-bucket uploads and reads.
type Presigner interface {
	// PresignUpload returns a URL the client can PUT object bytes to. The URL
	// authorizes an upload of contentType to key and expires after expiry.
	PresignUpload(ctx context.Context, key, contentType string, expiry time.Duration) (string, error)
	// PresignDownload returns a URL the client can GET the object bytes from
	// (e.g. to display an image). It expires after expiry.
	PresignDownload(ctx context.Context, key string, expiry time.Duration) (string, error)
}

// ResolveURL returns key unchanged when it is already an absolute URL (seeded
// or external images store a full URL in s3_key), otherwise a short-lived
// presigned download URL for the object key — falling back to key on error.
func ResolveURL(ctx context.Context, p Presigner, key string, ttl time.Duration) string {
	if key == "" || strings.HasPrefix(key, "http://") || strings.HasPrefix(key, "https://") {
		return key
	}
	if u, err := p.PresignDownload(ctx, key, ttl); err == nil {
		return u
	}
	return key
}

// StubPresigner is a development Presigner. It builds a plausible S3-style URL
// from the configured bucket/region but signs nothing — a PUT to it will NOT
// store anything. It exists so the presign flow is exercisable without AWS
// credentials and must never be used in production.
type StubPresigner struct {
	bucket string
	region string
}

// NewStubPresigner returns a StubPresigner for the given bucket and region.
func NewStubPresigner(bucket, region string) *StubPresigner {
	if bucket == "" {
		bucket = "bakecity"
	}
	if region == "" {
		region = "us-east-1"
	}
	return &StubPresigner{bucket: bucket, region: region}
}

var _ Presigner = (*StubPresigner)(nil)

// PresignUpload returns a stub presigned PUT URL. It performs no signing.
func (p *StubPresigner) PresignUpload(_ context.Context, key, _ string, expiry time.Duration) (string, error) {
	return fmt.Sprintf(
		"https://%s.s3.%s.amazonaws.com/%s?X-Amz-Algorithm=STUB&X-Amz-Expires=%d&X-Amz-SignedHeaders=host&X-Amz-Signature=stub-no-real-upload",
		p.bucket, p.region, key, int(expiry.Seconds()),
	), nil
}

// PresignDownload returns a stub presigned GET URL. It points at a plausible
// S3 object location but signs nothing, so the bytes won't actually load until
// a real presigner is configured. Empty key yields an empty URL.
func (p *StubPresigner) PresignDownload(_ context.Context, key string, expiry time.Duration) (string, error) {
	if key == "" {
		return "", nil
	}
	return fmt.Sprintf(
		"https://%s.s3.%s.amazonaws.com/%s?X-Amz-Algorithm=STUB&X-Amz-Expires=%d&X-Amz-SignedHeaders=host&X-Amz-Signature=stub-no-real-download",
		p.bucket, p.region, key, int(expiry.Seconds()),
	), nil
}
