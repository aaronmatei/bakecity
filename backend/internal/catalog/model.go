package catalog

import (
	"time"
)

// Product maps to the products table.
type Product struct {
	ID           string        `json:"id"`
	BakerID      string        `json:"baker_id"`
	CategoryID   string        `json:"category_id,omitempty"`
	Title        string        `json:"title"`
	Description  string        `json:"description,omitempty"`
	BasePrice    float64       `json:"base_price"`
	LeadTimeDays int           `json:"lead_time_days"`
	Active       bool          `json:"active"`
	RatingAvg    float64       `json:"rating_avg"`
	RatingCount  int           `json:"rating_count"`
	IsOnOffer    bool          `json:"is_on_offer"`
	DiscountPct  *int          `json:"discount_pct,omitempty"`
	Dietary      []string      `json:"dietary,omitempty"`
	IsCustom     bool          `json:"is_custom"`
	// AllowCustomRequest lets a fixed product also offer a custom-version path.
	AllowCustomRequest bool `json:"allow_custom_request"`
	Subcategory  string        `json:"subcategory_slug,omitempty"`
	CakeOccasion string        `json:"cake_occasion,omitempty"`
	CakeFlavor   string        `json:"cake_flavor,omitempty"`
	CakeFormat   string        `json:"cake_format,omitempty"`
	ImageURLs    []string      `json:"image_urls,omitempty"`
	// ImageMediaIDs are the media ids backing ImageURLs, same order — so an
	// editor can preserve/reorder/remove images on a replace.
	ImageMediaIDs []string      `json:"image_media_ids,omitempty"`
	Sizes         []ProductSize `json:"sizes,omitempty"`
	CreatedAt     time.Time     `json:"created_at"`
	UpdatedAt     time.Time     `json:"updated_at"`
}

// ProductSize is a weight/serving option with its own price (cakes are priced
// by weight in KE).
type ProductSize struct {
	ID       string   `json:"id"`
	Label    string   `json:"label"`
	WeightKg *float64 `json:"weight_kg,omitempty"`
	Serves   *int     `json:"serves,omitempty"`
	Price    float64  `json:"price"`
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

// SizeInput is a weight/serving option in a product create/update request.
type SizeInput struct {
	Label    string   `json:"label" binding:"required"`
	WeightKg *float64 `json:"weight_kg"`
	Serves   *int     `json:"serves"`
	Price    float64  `json:"price" binding:"required,gt=0"`
}

// CreateProductRequest is the payload for POST /products.
type CreateProductRequest struct {
	CategoryID   string      `json:"category_id"`
	Title        string      `json:"title" binding:"required"`
	Description  string      `json:"description"`
	BasePrice    float64     `json:"base_price" binding:"required,gt=0"`
	LeadTimeDays *int        `json:"lead_time_days"`
	Dietary      []string    `json:"dietary"`
	IsCustom     bool        `json:"is_custom"`
	AllowCustomRequest bool  `json:"allow_custom_request"`
	IsOnOffer    bool        `json:"is_on_offer"`
	DiscountPct  *int        `json:"discount_pct"`
	CakeOccasion string      `json:"cake_occasion"`
	CakeFlavor   string      `json:"cake_flavor"`
	CakeFormat   string      `json:"cake_format"`
	Sizes        []SizeInput `json:"sizes"`
	// ImageMediaIDs are uploaded media records (kind=product) to attach as the
	// product's images, in order.
	ImageMediaIDs []string `json:"image_media_ids"`
}

// UpdateProductRequest is the payload for PATCH /products/:id. Nil fields are
// left unchanged; a non-nil Sizes replaces the product's size set.
type UpdateProductRequest struct {
	CategoryID   *string      `json:"category_id"`
	Title        *string      `json:"title"`
	Description  *string      `json:"description"`
	BasePrice    *float64     `json:"base_price"`
	LeadTimeDays *int         `json:"lead_time_days"`
	Active       *bool        `json:"active"`
	Dietary      *[]string    `json:"dietary"`
	IsCustom     *bool        `json:"is_custom"`
	AllowCustomRequest *bool  `json:"allow_custom_request"`
	IsOnOffer    *bool        `json:"is_on_offer"`
	DiscountPct  *int         `json:"discount_pct"`
	CakeOccasion *string      `json:"cake_occasion"`
	CakeFlavor   *string      `json:"cake_flavor"`
	CakeFormat   *string      `json:"cake_format"`
	Sizes        *[]SizeInput `json:"sizes"`
	// ImageMediaIDs, when non-nil, replaces the product's image set.
	ImageMediaIDs *[]string `json:"image_media_ids"`
}

// CreateCategoryRequest is the payload for POST /categories (admin only).
type CreateCategoryRequest struct {
	Name string `json:"name" binding:"required"`
	Slug string `json:"slug"`
}

// ProductFilter narrows a product listing. Active is "true" (default), "false",
// or "all".
type ProductFilter struct {
	BakerID    string
	CategoryID string
	Active     string
	Limit      int
	Offset     int
}
