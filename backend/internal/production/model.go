package production

import (
	"time"
)

// Update maps to the production_updates table — one entry in an order's
// production timeline.
type Update struct {
	ID          string    `json:"id"`
	OrderID     string    `json:"order_id"`
	Stage       string    `json:"stage"`
	ProgressPct int       `json:"progress_pct"`
	Notes       string    `json:"notes,omitempty"`
	MediaID     string    `json:"media_id,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

// CreateUpdateRequest is the payload for posting a production update. A
// progress_pct of 100 marks production complete and moves the order to READY.
// An optional media_id attaches a progress photo (see the media presign flow).
type CreateUpdateRequest struct {
	Stage       string `json:"stage" binding:"required"`
	ProgressPct int    `json:"progress_pct" binding:"gte=0,lte=100"`
	Notes       string `json:"notes"`
	MediaID     string `json:"media_id"`
}
