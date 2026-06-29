package storage

import (
	"context"
	"strings"
	"time"
)

// LocalPresigner is a development Presigner that points uploads and downloads at
// the API's own blob endpoints (PUT/GET {base}/media/blob/{key}), backed by the
// media_blobs table. Unlike StubPresigner it actually stores and serves bytes,
// so the full upload flow works without an S3-compatible object store. It must
// never be used in production.
type LocalPresigner struct {
	baseURL string // public, device-reachable API base, e.g. http://192.168.1.10:8090
}

// NewLocalPresigner returns a LocalPresigner serving blobs under baseURL.
func NewLocalPresigner(baseURL string) *LocalPresigner {
	return &LocalPresigner{baseURL: strings.TrimRight(baseURL, "/")}
}

var _ Presigner = (*LocalPresigner)(nil)

// PresignUpload returns the API blob URL the client PUTs the bytes to.
func (p *LocalPresigner) PresignUpload(_ context.Context, key, _ string, _ time.Duration) (string, error) {
	return p.blobURL(key), nil
}

// PresignDownload returns the API blob URL the client GETs the bytes from.
func (p *LocalPresigner) PresignDownload(_ context.Context, key string, _ time.Duration) (string, error) {
	if key == "" {
		return "", nil
	}
	return p.blobURL(key), nil
}

func (p *LocalPresigner) blobURL(key string) string {
	return p.baseURL + "/media/blob/" + key
}
