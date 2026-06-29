-- Local development blob storage. When no S3/object store is configured, media
-- bytes are stored here and served by the API itself (see internal/media/blob.go
-- and storage.LocalPresigner), so the upload flow works end-to-end without AWS.
CREATE TABLE IF NOT EXISTS media_blobs (
    key          TEXT PRIMARY KEY,
    content_type TEXT NOT NULL DEFAULT 'application/octet-stream',
    bytes        BYTEA NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP
);
