// Package storage models the object store (S3 or a compatible service) that
// BakeCity uses for media. Clients upload bytes directly via a short-lived
// presigned URL; the API never proxies the upload itself.
package storage

import (
	"context"
	"fmt"
	"time"
)

// Presigner issues short-lived URLs for direct-to-bucket uploads.
type Presigner interface {
	// PresignUpload returns a URL the client can PUT object bytes to. The URL
	// authorizes an upload of contentType to key and expires after expiry.
	PresignUpload(ctx context.Context, key, contentType string, expiry time.Duration) (string, error)
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
