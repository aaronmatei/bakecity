package media

import (
	"time"
)

// Media kinds (the purpose of an upload), matching the media.kind column.
const (
	KindReference     = "reference"      // customer's design reference photo
	KindProduction    = "production"     // baker's production-stage photo
	KindDeliveryProof = "delivery_proof" // proof-of-delivery photo
	KindProduct       = "product"        // catalog product image
	KindKYC           = "kyc"            // baker's identity document (owner-scoped)
)

// Media upload lifecycle statuses.
const (
	StatusPending  = "pending"  // record created, bytes not yet uploaded
	StatusUploaded = "uploaded" // client confirmed the upload completed
	StatusReady    = "ready"    // processed (e.g. thumbnailed) and servable
)

// Media maps to the media table. URL and ThumbURL are not stored; they are
// short-lived presigned download URLs resolved when the record is served.
type Media struct {
	ID        string    `json:"id"`
	OrderID   string    `json:"order_id,omitempty"`
	OwnerID   string    `json:"owner_id"`
	Kind      string    `json:"kind"`
	S3Key     string    `json:"s3_key"`
	ThumbKey  string    `json:"thumb_key,omitempty"`
	Status    string    `json:"status"`
	URL       string    `json:"url,omitempty"`
	ThumbURL  string    `json:"thumb_url,omitempty"`
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
