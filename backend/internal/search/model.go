package search

// BakerSearchQuery holds geospatial baker search parameters.
type BakerSearchQuery struct {
	Lat      float64
	Lng      float64
	RadiusKM float64
	Q        string
}

// ProductSearchQuery holds product search parameters.
type ProductSearchQuery struct {
	Q          string
	CategoryID string
	MaxPrice   float64
}
