package media

import (
	"time"
)

// Media maps to the media table.
type Media struct {
	ID        string    `json:"id"`
	OrderID   string    `json:"order_id,omitempty"`
	OwnerID   string    `json:"owner_id"`
	Kind      string    `json:"kind"`
	S3Key     string    `json:"s3_key"`
	ThumbKey  string    `json:"thumb_key,omitempty"`
	Status    string    `json:"status"`
	CreatedAt time.Time `json:"created_at"`
}

// PresignRequest is the payload for requesting an upload URL.
type PresignRequest struct {
	Kind        string `json:"kind" binding:"required"`
	ContentType string `json:"content_type" binding:"required"`
	OrderID     string `json:"order_id"`
}

// PresignResponse contains the presigned upload URL and object key.
type PresignResponse struct {
	UploadURL string `json:"upload_url"`
	S3Key     string `json:"s3_key"`
	MediaID   string `json:"media_id"`
}
