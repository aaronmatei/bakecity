package storage

import (
	"context"
	"strings"
	"testing"
	"time"
)

func TestStubPresignUpload(t *testing.T) {
	p := NewStubPresigner("my-bucket", "eu-west-1")
	url, err := p.PresignUpload(context.Background(), "production/abc.jpg", "image/jpeg", 15*time.Minute)
	if err != nil {
		t.Fatalf("PresignUpload: %v", err)
	}
	for _, want := range []string{"my-bucket", "eu-west-1", "production/abc.jpg", "X-Amz-Expires=900"} {
		if !strings.Contains(url, want) {
			t.Errorf("url %q missing %q", url, want)
		}
	}
}

func TestStubPresignerDefaults(t *testing.T) {
	p := NewStubPresigner("", "")
	url, err := p.PresignUpload(context.Background(), "k", "image/png", time.Minute)
	if err != nil {
		t.Fatalf("PresignUpload: %v", err)
	}
	if !strings.Contains(url, "bakecity") || !strings.Contains(url, "us-east-1") {
		t.Errorf("defaults not applied: %q", url)
	}
}
