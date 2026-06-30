package reviews

import (
	"time"
)

// Review maps to the reviews table.
type Review struct {
	ID           string    `json:"id"`
	OrderID      string    `json:"order_id"`
	CustomerID   string    `json:"customer_id"`
	CustomerName string    `json:"author_name,omitempty"`
	BakerID      string    `json:"baker_id"`
	Rating       int       `json:"rating"`
	Body         string    `json:"body,omitempty"`
	CreatedAt    time.Time `json:"created_at"`
}

// BakerReviews is a baker's review list with aggregate rating.
type BakerReviews struct {
	BakerID       string   `json:"baker_id"`
	AverageRating float64  `json:"average_rating"`
	Count         int      `json:"count"`
	// Distribution holds the count of reviews per star, index 0 = 1-star … 4 =
	// 5-star, over ALL of the baker's reviews (not just the returned page).
	Distribution [5]int   `json:"distribution"`
	Reviews      []Review `json:"reviews"`
}

// CreateReviewRequest is the payload for posting a review.
type CreateReviewRequest struct {
	OrderID string `json:"order_id" binding:"required"`
	Rating  int    `json:"rating" binding:"required,min=1,max=5"`
	Body    string `json:"body"`
}
