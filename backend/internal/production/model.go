package production

import (
	"time"
)

// Update maps to the production_updates table.
type Update struct {
	ID          string    `json:"id"`
	OrderID     string    `json:"order_id"`
	Stage       string    `json:"stage"`
	ProgressPct int       `json:"progress_pct"`
	Notes       string    `json:"notes,omitempty"`
	CreatedAt   time.Time `json:"created_at"`
}

// CreateUpdateRequest is the payload for posting a production update.
type CreateUpdateRequest struct {
	Stage       string `json:"stage" binding:"required"`
	ProgressPct int    `json:"progress_pct"`
	Notes       string `json:"notes"`
}
