package reviews

import (
	"time"
)

// Review maps to the reviews table.
type Review struct {
	ID         string    `json:"id"`
	OrderID    string    `json:"order_id"`
	CustomerID string    `json:"customer_id"`
	BakerID    string    `json:"baker_id"`
	Rating     int       `json:"rating"`
	Body       string    `json:"body,omitempty"`
	CreatedAt  time.Time `json:"created_at"`
}

// BakerReviews is a baker's review list with aggregate rating.
type BakerReviews struct {
	BakerID       string   `json:"baker_id"`
	AverageRating float64  `json:"average_rating"`
	Count         int      `json:"count"`
	Reviews       []Review `json:"reviews"`
}

// CreateReviewRequest is the payload for posting a review.
type CreateReviewRequest struct {
	OrderID string `json:"order_id" binding:"required"`
	Rating  int    `json:"rating" binding:"required,min=1,max=5"`
	Body    string `json:"body"`
}
