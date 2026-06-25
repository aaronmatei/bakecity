package catalog

import (
	"time"
)

// Product maps to the products table.
type Product struct {
	ID           string    `json:"id"`
	BakerID      string    `json:"baker_id"`
	CategoryID   string    `json:"category_id,omitempty"`
	Title        string    `json:"title"`
	Description  string    `json:"description,omitempty"`
	BasePrice    float64   `json:"base_price"`
	LeadTimeDays int       `json:"lead_time_days"`
	Active       bool      `json:"active"`
	CreatedAt    time.Time `json:"created_at"`
	UpdatedAt    time.Time `json:"updated_at"`
}

// ProductImage maps to the product_images table.
type ProductImage struct {
	ID        string `json:"id"`
	ProductID string `json:"product_id"`
	MediaID   string `json:"media_id"`
	Position  int    `json:"position"`
}

// Category maps to the product_categories table.
type Category struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Slug string `json:"slug"`
}

// CreateProductRequest is the payload for POST /products.
type CreateProductRequest struct {
	CategoryID  string  `json:"category_id"`
	Title       string  `json:"title" binding:"required"`
	Description string  `json:"description"`
	BasePrice   float64 `json:"base_price" binding:"required"`
}
