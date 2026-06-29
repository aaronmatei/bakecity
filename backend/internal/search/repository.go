package search

import (
	"context"
	"strconv"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/corebalt/bakecity/pkg"
)

// Repository runs discovery queries.
type Repository struct {
	db *pgxpool.Pool
}

// NewRepository constructs a Repository.
func NewRepository(db *pgxpool.Pool) *Repository {
	return &Repository{db: db}
}

// argBuilder accumulates positional query parameters.
type argBuilder struct{ args []any }

func (b *argBuilder) add(v any) string {
	b.args = append(b.args, v)
	return "$" + strconv.Itoa(len(b.args))
}

// SearchBakers finds approved bakers matching the query.
func (r *Repository) SearchBakers(ctx context.Context, q BakerSearchQuery) ([]BakerResult, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	b := &argBuilder{}
	geo := q.Lat != nil && q.Lng != nil

	distExpr := "NULL::float8"
	var pointExpr string
	if geo {
		pointExpr = "ST_SetSRID(ST_MakePoint(" + b.add(*q.Lng) + ", " + b.add(*q.Lat) + "), 4326)::geography"
		distExpr = "ST_Distance(bp.location, " + pointExpr + ") / 1000"
	}

	var sb strings.Builder
	sb.WriteString(`SELECT bp.id, bp.business_name, COALESCE(bp.bio, ''), bp.status,
	    bp.lead_time_days, bp.delivery_radius_km,
	    ST_Y(bp.location::geometry), ST_X(bp.location::geometry),
	    COALESCE(rv.avg, 0), COALESCE(rv.cnt, 0), ` + distExpr + `
	  FROM baker_profiles bp
	  LEFT JOIN (
	      SELECT baker_id, AVG(rating)::float8 AS avg, COUNT(*) AS cnt
	        FROM reviews GROUP BY baker_id
	  ) rv ON rv.baker_id = bp.id
	 WHERE bp.status = 'approved'`)

	// A chosen radius searches within that distance of the user. Without one we
	// don't distance-gate at all, so browsing always surfaces approved bakers
	// (sorted nearest-first when a location is known); whether a baker delivers
	// to the user is a per-result detail derived from distance vs their radius.
	if geo && q.RadiusKM != nil {
		sb.WriteString(" AND bp.location IS NOT NULL AND ST_DWithin(bp.location, " +
			pointExpr + ", " + b.add(*q.RadiusKM*1000) + ")")
	}
	if p := productExists(b, "bp.id", q.CategorySlug, q.MinPrice, q.MaxPrice); p != "" {
		sb.WriteString(" AND " + p)
	}
	if q.MinRating != nil {
		sb.WriteString(" AND COALESCE(rv.avg, 0) >= " + b.add(*q.MinRating))
	}
	if q.Q != "" {
		sb.WriteString(" AND bp.business_name ILIKE " + b.add("%"+q.Q+"%"))
	}

	if geo {
		sb.WriteString(" ORDER BY 11 ASC NULLS LAST")
	} else {
		sb.WriteString(" ORDER BY COALESCE(rv.avg, 0) DESC, bp.created_at DESC")
	}
	sb.WriteString(" LIMIT " + b.add(q.Limit) + " OFFSET " + b.add(q.Offset))

	rows, err := r.db.Query(ctx, sb.String(), b.args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]BakerResult, 0)
	for rows.Next() {
		var res BakerResult
		if err := rows.Scan(&res.ID, &res.BusinessName, &res.Bio, &res.Status,
			&res.LeadTimeDays, &res.DeliveryRadiusKM, &res.Lat, &res.Lng,
			&res.AvgRating, &res.ReviewCount, &res.DistanceKM); err != nil {
			return nil, err
		}
		out = append(out, res)
	}
	return out, rows.Err()
}

// SearchProducts finds active products of approved bakers matching the query.
func (r *Repository) SearchProducts(ctx context.Context, q ProductSearchQuery) ([]ProductResult, error) {
	if r.db == nil {
		return nil, pkg.ErrNotImplemented
	}
	b := &argBuilder{}
	geo := q.Lat != nil && q.Lng != nil

	distExpr := "NULL::float8"
	var pointExpr string
	if geo {
		pointExpr = "ST_SetSRID(ST_MakePoint(" + b.add(*q.Lng) + ", " + b.add(*q.Lat) + "), 4326)::geography"
		distExpr = "ST_Distance(bp.location, " + pointExpr + ") / 1000"
	}

	// Image URLs: media.s3_key holds the full URL for seeded/external product
	// images, ordered by position.
	const imagesExpr = `COALESCE(ARRAY(
		SELECT m.s3_key FROM product_images pim JOIN media m ON m.id = pim.media_id
		WHERE pim.product_id = p.id ORDER BY pim.position), '{}'::text[])`

	var sb strings.Builder
	sb.WriteString(`SELECT p.id, p.baker_id, bp.business_name, COALESCE(p.category_id::text, ''),
	    p.title, COALESCE(p.description, ''), p.base_price, p.lead_time_days,
	    p.rating_avg, p.rating_count, p.is_on_offer, p.discount_pct, p.dietary,
	    COALESCE(p.cake_occasion,''), COALESCE(p.cake_flavor,''), COALESCE(p.cake_format,''),
	    ` + imagesExpr + `, ` + distExpr + ` AS distance_km, p.created_at
	  FROM products p
	  JOIN baker_profiles bp ON bp.id = p.baker_id
	  LEFT JOIN product_categories c ON c.id = p.category_id
	 WHERE p.active = true AND bp.status = 'approved'`)

	if q.BakerID != "" {
		sb.WriteString(" AND p.baker_id = " + b.add(q.BakerID))
	}
	if q.CategorySlug != "" {
		sb.WriteString(" AND c.slug = " + b.add(q.CategorySlug))
	}
	if q.Occasion != "" {
		sb.WriteString(" AND p.cake_occasion = " + b.add(q.Occasion))
	}
	if q.Flavor != "" {
		sb.WriteString(" AND p.cake_flavor = " + b.add(q.Flavor))
	}
	if q.Format != "" {
		sb.WriteString(" AND p.cake_format = " + b.add(q.Format))
	}
	if len(q.Dietary) > 0 {
		sb.WriteString(" AND p.dietary @> " + b.add(q.Dietary)) // contains all
	}
	if q.MinPrice != nil {
		sb.WriteString(" AND p.base_price >= " + b.add(*q.MinPrice))
	}
	if q.MaxPrice != nil {
		sb.WriteString(" AND p.base_price <= " + b.add(*q.MaxPrice))
	}
	if q.MinRating != nil {
		sb.WriteString(" AND p.rating_avg >= " + b.add(*q.MinRating))
	}
	if q.OnOffer != nil && *q.OnOffer {
		sb.WriteString(" AND p.is_on_offer = true")
	}
	if q.Q != "" {
		w := b.add("%" + q.Q + "%")
		sb.WriteString(" AND (p.title ILIKE " + w + " OR p.description ILIKE " + w + ")")
	}

	sb.WriteString(" ORDER BY " + productSort(q.Sort, geo))
	sb.WriteString(" LIMIT " + b.add(q.Limit) + " OFFSET " + b.add(q.Offset))

	rows, err := r.db.Query(ctx, sb.String(), b.args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	out := make([]ProductResult, 0)
	for rows.Next() {
		var res ProductResult
		if err := rows.Scan(&res.ID, &res.BakerID, &res.BakerName, &res.CategoryID,
			&res.Title, &res.Description, &res.BasePrice, &res.LeadTimeDays,
			&res.RatingAvg, &res.RatingCount, &res.IsOnOffer, &res.DiscountPct, &res.Dietary,
			&res.CakeOccasion, &res.CakeFlavor, &res.CakeFormat,
			&res.ImageURLs, &res.DistanceKM, &res.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, res)
	}
	return out, rows.Err()
}

// productSort maps a sort key to an ORDER BY clause. The distance column is the
// second-to-last SELECT column (used for "nearest").
func productSort(sort string, geo bool) string {
	switch sort {
	case "top_rated":
		return "p.rating_avg DESC, p.rating_count DESC"
	case "best_selling":
		return "p.rating_count DESC, p.rating_avg DESC"
	case "price_asc":
		return "p.base_price ASC"
	case "price_desc":
		return "p.base_price DESC"
	case "newest":
		return "p.created_at DESC"
	case "nearest":
		if geo {
			return "distance_km ASC NULLS LAST"
		}
		return "p.created_at DESC"
	default:
		if geo {
			return "distance_km ASC NULLS LAST"
		}
		return "p.created_at DESC"
	}
}

// productExists builds an EXISTS predicate matching an active product owned by
// bakerCol within the given category/price constraints, or "" if none apply.
func productExists(b *argBuilder, bakerCol, categorySlug string, minPrice, maxPrice *float64) string {
	conds := []string{"p.baker_id = " + bakerCol, "p.active = true"}
	if categorySlug != "" {
		conds = append(conds, "pc.slug = "+b.add(categorySlug))
	}
	if minPrice != nil {
		conds = append(conds, "p.base_price >= "+b.add(*minPrice))
	}
	if maxPrice != nil {
		conds = append(conds, "p.base_price <= "+b.add(*maxPrice))
	}
	if len(conds) == 2 { // only the always-on baker/active conds → no real filter
		return ""
	}
	return "EXISTS (SELECT 1 FROM products p LEFT JOIN product_categories pc ON pc.id = p.category_id WHERE " +
		strings.Join(conds, " AND ") + ")"
}
