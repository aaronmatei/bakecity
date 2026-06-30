// Command seed_catalog seeds a rich, realistic product catalog across the
// bakers already in the database. It is idempotent: products upsert on
// (baker_id, slug), and sizes/images are replaced in place, so re-running never
// duplicates. Run with `make seed`.
//
// It never invents bakers — it reads approved bakers from the DB and gives each
// a specialty so catalogs differ. Prices are KES placeholders bakers will edit.
package main

import (
	"context"
	"fmt"
	"hash/fnv"
	"log"
	"math/rand"
	"os"
	"regexp"
	"strings"

	"github.com/jackc/pgx/v5/pgxpool"
)

// ---- Taxonomy ----------------------------------------------------------------

type categoryDef struct {
	slug, name, icon string
	sort             int
	featured         bool
}

// The full category taxonomy (icons are Material icon names the app can map).
var categories = []categoryDef{
	{"cakes", "Cakes", "cake", 1, true},
	{"cupcakes", "Cupcakes", "bakery_dining", 2, true},
	{"cookies", "Cookies", "cookie", 3, true},
	{"doughnuts", "Doughnuts", "donut_large", 4, false},
	{"pastries", "Pastries", "croissant", 5, true},
	{"bread", "Bread", "bakery_dining", 6, true},
	{"brownies", "Brownies & Bars", "grid_view", 7, true},
	{"pies-tarts", "Pies & Tarts", "pie_chart", 8, true},
	{"desserts", "Desserts", "icecream", 9, false},
	{"breakfast-snacks", "Breakfast & Snacks", "free_breakfast", 10, true},
	{"gift-boxes", "Gift Boxes", "card_giftcard", 11, true},
	{"chocolates", "Chocolates & Confectionery", "cookie", 12, false},
	{"healthy-special", "Healthy & Special Diet", "eco", 13, false},
	{"custom-orders", "Custom Orders", "design_services", 14, true},
}

var (
	occasions = []string{"birthday", "wedding", "anniversary", "graduation", "baby_shower", "gender_reveal", "corporate", "generic"}
	flavors   = []string{"chocolate", "vanilla", "red_velvet", "black_forest", "fruit", "carrot", "lemon", "coffee", "cheesecake"}
	formats   = []string{"standard", "bento", "photo", "tiered", "sheet", "number"}
	dietaryAll = []string{"eggless", "vegan", "gluten_free", "sugar_free", "halal"}
)

func titleCase(s string) string {
	s = strings.ReplaceAll(s, "_", " ")
	return strings.ToUpper(s[:1]) + s[1:]
}

// A baker specialty: which categories they sell, and whether cakes dominate.
type specialty struct {
	name      string
	cats      []string
	cakeHeavy bool
}

var specialties = []specialty{
	{"Wedding & celebration cakes", []string{"cakes", "cupcakes", "desserts", "gift-boxes"}, true},
	{"Everyday cakes & cupcakes", []string{"cakes", "cupcakes", "cookies", "brownies"}, true},
	{"Artisan bread & pastries", []string{"bread", "pastries", "breakfast-snacks", "pies-tarts"}, false},
	{"Cookies, brownies & gifting", []string{"cookies", "brownies", "gift-boxes", "chocolates"}, false},
	{"Healthy & special diet", []string{"healthy-special", "cakes", "bread", "desserts"}, true},
	{"Full-service bakery", []string{"cakes", "cupcakes", "cookies", "bread", "pastries", "brownies", "pies-tarts", "desserts", "doughnuts"}, true},
}

// Non-cake item pools: name, price band (KES), lead-time days.
type item struct {
	name     string
	lo, hi   float64
	lead     int
	packable bool // sells per-piece + packs (cupcakes, cookies)
}

var catItems = map[string][]item{
	"cupcakes": {
		{"Chocolate Cupcakes", 100, 160, 1, true}, {"Vanilla Cupcakes", 90, 150, 1, true},
		{"Red Velvet Cupcakes", 120, 180, 1, true}, {"Rainbow Cupcakes", 110, 170, 1, true},
		{"Salted Caramel Cupcakes", 130, 180, 1, true}, {"Lemon Cupcakes", 100, 160, 1, true},
	},
	"cookies": {
		{"Chocolate Chip Cookies", 60, 120, 0, true}, {"Double Chocolate Cookies", 80, 140, 0, true},
		{"Oatmeal Raisin Cookies", 60, 110, 0, true}, {"Peanut Butter Cookies", 70, 130, 0, true},
		{"Shortbread Cookies", 70, 120, 1, true}, {"Almond Biscotti", 90, 150, 1, true},
		{"Decorated Sugar Cookies", 120, 200, 2, true},
	},
	"doughnuts": {
		{"Glazed Doughnuts", 70, 120, 0, true}, {"Chocolate Doughnuts", 80, 130, 0, true},
		{"Strawberry Doughnuts", 80, 130, 0, true}, {"Boston Cream Doughnuts", 100, 150, 1, true},
		{"Cinnamon Sugar Mini Doughnuts", 60, 110, 0, true},
	},
	"pastries": {
		{"Butter Croissant", 90, 150, 0, false}, {"Pain au Chocolat", 110, 170, 0, false},
		{"Almond Danish", 120, 190, 1, false}, {"Cinnamon Roll", 100, 170, 0, false},
		{"Apple Turnover", 110, 180, 1, false}, {"Chocolate Éclair", 120, 200, 1, false},
	},
	"bread": {
		{"White Sandwich Loaf", 60, 120, 0, false}, {"Whole Wheat Loaf", 80, 150, 0, false},
		{"Milk Bread", 90, 160, 0, false}, {"Sourdough Loaf", 200, 350, 1, false},
		{"French Baguette", 120, 200, 0, false}, {"Garlic Bread", 150, 250, 0, false},
		{"Brioche Buns (6)", 200, 320, 1, false}, {"Burger Buns (6)", 180, 300, 1, false},
	},
	"brownies": {
		{"Classic Fudge Brownies", 120, 200, 0, true}, {"Walnut Brownies", 140, 220, 0, true},
		{"Salted Caramel Blondies", 140, 230, 1, true}, {"Triple Chocolate Brownies", 150, 250, 1, true},
	},
	"pies-tarts": {
		{"Apple Pie", 600, 1200, 1, false}, {"Chicken Pie", 500, 1000, 1, false},
		{"Beef Pie", 500, 1000, 1, false}, {"Fresh Fruit Tart", 700, 1300, 2, false},
		{"Lemon Meringue Tart", 700, 1200, 2, false}, {"Quiche Lorraine", 600, 1100, 1, false},
	},
	"desserts": {
		{"Tiramisu (tub)", 600, 1100, 1, false}, {"Vanilla Panna Cotta", 350, 600, 1, false},
		{"Strawberry Trifle", 500, 900, 1, false}, {"Chocolate Mousse", 350, 600, 1, false},
	},
	"breakfast-snacks": {
		{"Blueberry Muffins", 90, 160, 0, true}, {"Banana Bread", 250, 450, 1, false},
		{"Buttermilk Scones", 80, 140, 0, true}, {"Sausage Rolls", 120, 200, 0, true},
		{"Beef Samosas (4)", 150, 280, 0, false},
	},
	"gift-boxes": {
		{"Cookie Gift Box", 1000, 2000, 2, false}, {"Brownie Gift Box", 1200, 2200, 2, false},
		{"Mixed Pastry Box", 1300, 2500, 2, false}, {"Cake & Flowers Box", 2000, 3500, 3, false},
	},
	"chocolates": {
		{"Chocolate Cake Pops", 120, 200, 1, true}, {"Assorted Truffles (6)", 600, 1100, 2, false},
		{"French Macarons (6)", 700, 1300, 2, false}, {"Chocolate Fudge Slab", 400, 700, 1, false},
	},
	"healthy-special": {
		{"Gluten-free Chocolate Cake", 2200, 3500, 2, false}, {"Vegan Banana Loaf", 350, 600, 1, false},
		{"Keto Almond Bread", 400, 700, 1, false}, {"Sugar-free Carrot Cake", 2000, 3200, 2, false},
		{"High-protein Muffins", 120, 200, 0, true},
	},
}

// imageKeywords maps a category to loremflickr search terms for seed photos.
var imageKeywords = map[string]string{
	"cakes": "cake", "cupcakes": "cupcake", "cookies": "cookie,biscuit",
	"doughnuts": "donut", "pastries": "pastry,croissant", "bread": "bread,bakery",
	"brownies": "brownie,chocolate", "pies-tarts": "pie,tart", "desserts": "dessert",
	"breakfast-snacks": "muffin,breakfast", "gift-boxes": "bakery,gift",
	"chocolates": "chocolate,truffle", "healthy-special": "healthy,cake",
	"custom-orders": "celebration,cake",
}

// ---- Seed model --------------------------------------------------------------

type seedSize struct {
	label    string
	weightKg float64
	serves   int
	price    float64
}

type seedProduct struct {
	slug, title, desc                  string
	categorySlug, subcategory          string
	basePrice                          float64
	lead                               int
	dietary                            []string
	isCustom, onOffer, allowCustom     bool
	discountPct                        int
	ratingAvg                          float64
	ratingCount                        int
	occasion, flavor, format           string
	sizes                              []seedSize
	images                             []string
}

var slugRe = regexp.MustCompile(`[^a-z0-9]+`)

func slugify(parts ...string) string {
	s := strings.ToLower(strings.Join(parts, "-"))
	s = slugRe.ReplaceAllString(s, "-")
	return strings.Trim(s, "-")
}

func hashSeed(s string) int64 {
	h := fnv.New64a()
	_, _ = h.Write([]byte(s))
	return int64(h.Sum64() & 0x7fffffffffffffff)
}

func pick[T any](rng *rand.Rand, xs []T) T { return xs[rng.Intn(len(xs))] }

func priceIn(rng *rand.Rand, lo, hi float64) float64 {
	return float64(int((lo+rng.Float64()*(hi-lo))/10) * 10) // round to 10 KES
}

func imageURL(keywords, slug string, n int) string {
	return fmt.Sprintf("https://loremflickr.com/600/450/%s?lock=%d", keywords, int(hashSeed(slug))%100000+n)
}

// coverURL is a wide storefront cover photo, deterministic per baker.
func coverURL(bakerID string) string {
	return fmt.Sprintf("https://loremflickr.com/1200/600/bakery,cake,pastry?lock=%d", int(hashSeed(bakerID))%100000)
}

// avatarURL is a square logo/avatar photo, deterministic per baker.
func avatarURL(bakerID string) string {
	return fmt.Sprintf("https://loremflickr.com/300/300/bakery,logo,cake?lock=%d", int(hashSeed(bakerID))%100000+7)
}

// seedBakerMedia gives a baker a storefront cover + avatar (owner-scoped media
// with full URLs). Idempotent: only inserts a kind if it's missing.
func seedBakerMedia(ctx context.Context, db *pgxpool.Pool, b bakerRow) {
	// kind is an internal constant, inlined as a literal so Postgres can deduce
	// the parameter types cleanly (only $1=owner_id, $2=url are bound).
	insert := func(kind, url string) {
		if _, err := db.Exec(ctx, fmt.Sprintf(
			`INSERT INTO media (owner_id, kind, s3_key, status)
			 SELECT $1, '%[1]s', $2, 'uploaded'
			 WHERE NOT EXISTS (
			   SELECT 1 FROM media WHERE owner_id = $1 AND kind = '%[1]s' AND order_id IS NULL
			 )`, kind),
			b.userID, url); err != nil {
			log.Printf("seed %s for %s: %v", kind, b.name, err)
		}
	}
	insert("baker_cover", coverURL(b.id))
	insert("baker_avatar", avatarURL(b.id))
}

// ---- Catalog generation ------------------------------------------------------

func buildCatalog(rng *rand.Rand, spec specialty) []seedProduct {
	var out []seedProduct
	for _, c := range spec.cats {
		switch c {
		case "cakes":
			out = append(out, buildCakes(rng, spec)...)
		default:
			out = append(out, buildSimple(rng, c)...)
		}
	}
	// Every baker gets a custom-cake template that opens the quote flow.
	out = append(out, seedProduct{
		slug:         "custom-cake",
		title:        "Custom Cake — your design",
		desc:         "Tell us your occasion, flavour, size and design and we'll quote a one-of-a-kind cake just for you.",
		categorySlug: "custom-orders",
		basePrice:    0,
		lead:         3,
		isCustom:     true,
		ratingAvg:    0,
		images:       []string{imageURL(imageKeywords["custom-orders"], "custom-cake", 0)},
	})
	return out
}

func buildCakes(rng *rand.Rand, spec specialty) []seedProduct {
	n := 12 + rng.Intn(9) // 12–20 cakes
	if spec.cakeHeavy {
		n = 16 + rng.Intn(13) // 16–28
	}
	seen := map[string]bool{}
	var out []seedProduct
	for len(out) < n {
		occ := pick(rng, occasions)
		fl := pick(rng, flavors)
		fmt_ := pick(rng, formats)
		// Wedding/tiered favour tiered formats; keep some coherence.
		if occ == "wedding" && rng.Float64() < 0.6 {
			fmt_ = "tiered"
		}
		slug := slugify("cake", fl, occ, fmt_)
		if seen[slug] {
			continue
		}
		seen[slug] = true
		out = append(out, makeCake(rng, occ, fl, fmt_, slug))
	}
	return out
}

func makeCake(rng *rand.Rand, occ, fl, fmt_, slug string) seedProduct {
	perKg := priceIn(rng, 1800, 3200)
	lead := 1 + rng.Intn(3)
	mult := 1.0
	switch fmt_ {
	case "tiered":
		mult, lead = 1.5, 5+rng.Intn(10)
	case "photo", "number":
		mult = 1.15
	}
	if occ == "wedding" {
		mult *= 1.2
		if lead < 5 {
			lead = 5 + rng.Intn(8)
		}
	}

	var sizes []seedSize
	switch fmt_ {
	case "bento":
		sizes = []seedSize{{"Bento (serves 2–3)", 0.4, 3, priceIn(rng, 1200, 1800)}}
	case "tiered":
		for _, w := range []struct {
			l string
			kg float64
			s  int
		}{{"1.5kg · 2 tiers", 1.5, 12}, {"2.5kg · 2 tiers", 2.5, 20}, {"4kg · 3 tiers", 4, 40}} {
			sizes = append(sizes, seedSize{w.l, w.kg, w.s, float64(int(perKg*w.kg*mult/10)*10)})
		}
	default:
		for _, w := range []struct {
			l string
			kg float64
			s  int
		}{{"0.5kg", 0.5, 4}, {"1kg", 1, 8}, {"1.5kg", 1.5, 12}, {"2kg", 2, 16}, {"3kg", 3, 25}} {
			sizes = append(sizes, seedSize{w.l, w.kg, w.s, float64(int(perKg*w.kg*mult/10)*10)})
		}
	}
	base := sizes[0].price

	diet := []string{}
	if rng.Float64() < 0.35 {
		diet = append(diet, pick(rng, dietaryAll))
		if rng.Float64() < 0.2 {
			diet = append(diet, pick(rng, dietaryAll))
		}
		diet = dedupe(diet)
	}

	onOffer := rng.Float64() < 0.15
	disc := 0
	if onOffer {
		disc = 10 + rng.Intn(16) // 10–25
	}

	title := fmt.Sprintf("%s %s Cake", titleCase(fl), titleCase(occ))
	if fmt_ != "standard" {
		title = fmt.Sprintf("%s %s Cake — %s", titleCase(fl), titleCase(occ), titleCase(fmt_))
	}
	desc := fmt.Sprintf(
		"A %s %s cake for your %s — moist, freshly baked and finished to order%s.",
		strings.ToLower(titleCase(fl)), strings.ReplaceAll(fmt_, "_", " "),
		strings.ReplaceAll(occ, "_", " "),
		dietSuffix(diet))

	return seedProduct{
		slug: slug, title: title, desc: desc,
		categorySlug: "cakes", subcategory: fl,
		basePrice: base, lead: lead, dietary: diet,
		onOffer: onOffer, discountPct: disc,
		// Standard cakes are bought as-is, but also open to a custom version.
		allowCustom: true,
		ratingAvg:   ratingFor(rng), ratingCount: 5 + rng.Intn(120),
		occasion: occ, flavor: fl, format: fmt_,
		sizes:  sizes,
		images: []string{imageURL(imageKeywords["cakes"], slug, 0), imageURL(fl+",cake", slug, 1)},
	}
}

func buildSimple(rng *rand.Rand, catSlug string) []seedProduct {
	pool := catItems[catSlug]
	if len(pool) == 0 {
		return nil
	}
	rng.Shuffle(len(pool), func(i, j int) { pool[i], pool[j] = pool[j], pool[i] })
	take := 3 + rng.Intn(4)
	if take > len(pool) {
		take = len(pool)
	}
	var out []seedProduct
	for _, it := range pool[:take] {
		base := priceIn(rng, it.lo, it.hi)
		slug := slugify(catSlug, it.name)
		diet := []string{}
		if catSlug == "healthy-special" {
			diet = []string{pick(rng, []string{"vegan", "gluten_free", "sugar_free"})}
		} else if rng.Float64() < 0.2 {
			diet = []string{pick(rng, dietaryAll)}
		}
		var sizes []seedSize
		if it.packable {
			sizes = []seedSize{
				{"Single", 0, 1, base},
				{"6-pack", 0, 6, float64(int(base*5.5/10) * 10)},
				{"12-pack", 0, 12, float64(int(base*10/10) * 10)},
			}
		}
		onOffer := rng.Float64() < 0.15
		disc := 0
		if onOffer {
			disc = 10 + rng.Intn(16)
		}
		out = append(out, seedProduct{
			slug: slug, title: it.name,
			desc:         fmt.Sprintf("Freshly baked %s, made to order%s.", strings.ToLower(it.name), dietSuffix(diet)),
			categorySlug: catSlug, basePrice: base, lead: it.lead, dietary: diet,
			onOffer: onOffer, discountPct: disc,
			ratingAvg: ratingFor(rng), ratingCount: 4 + rng.Intn(90),
			sizes:  sizes,
			images: []string{imageURL(imageKeywords[catSlug], slug, 0)},
		})
	}
	return out
}

func ratingFor(rng *rand.Rand) float64 {
	return float64(int((3.6+rng.Float64()*1.4)*10)) / 10 // 3.6–5.0
}
func dietSuffix(d []string) string {
	if len(d) == 0 {
		return ""
	}
	for i := range d {
		d[i] = strings.ReplaceAll(d[i], "_", "-")
	}
	return " (" + strings.Join(d, ", ") + ")"
}
func dedupe(xs []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, x := range xs {
		if !seen[x] {
			seen[x] = true
			out = append(out, x)
		}
	}
	return out
}

// ---- Persistence -------------------------------------------------------------

type bakerRow struct{ id, userID, name string }

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		log.Fatal("DATABASE_URL is required")
	}
	ctx := context.Background()
	db, err := pgxpool.New(ctx, dsn)
	if err != nil {
		log.Fatalf("connect: %v", err)
	}
	defer db.Close()

	catID := seedCategories(ctx, db)
	bakers := approvedBakers(ctx, db)
	if len(bakers) == 0 {
		log.Fatal("no approved bakers to seed for")
	}

	total := 0
	for i, b := range bakers {
		spec := specialties[i%len(specialties)]
		seedBakerMedia(ctx, db, b)
		rng := rand.New(rand.NewSource(hashSeed(b.id)))
		for _, p := range buildCatalog(rng, spec) {
			upsertProduct(ctx, db, b, p, catID)
			total++
		}
		log.Printf("seeded %-26s as %-28s", b.name, spec.name)
	}
	// Drop product media orphaned by replaced image sets on earlier runs.
	_, _ = db.Exec(ctx, `DELETE FROM media WHERE kind='product' AND id NOT IN (SELECT media_id FROM product_images)`)
	log.Printf("done: %d products across %d bakers (idempotent)", total, len(bakers))
}

func seedCategories(ctx context.Context, db *pgxpool.Pool) map[string]string {
	ids := map[string]string{}
	for _, c := range categories {
		var id string
		err := db.QueryRow(ctx,
			`INSERT INTO product_categories (name, slug, icon, sort_order, featured)
			 VALUES ($1,$2,$3,$4,$5)
			 ON CONFLICT (slug) DO UPDATE SET name=$1, icon=$3, sort_order=$4, featured=$5
			 RETURNING id`,
			c.name, c.slug, c.icon, c.sort, c.featured).Scan(&id)
		if err != nil {
			log.Fatalf("seed category %s: %v", c.slug, err)
		}
		ids[c.slug] = id
	}
	return ids
}

func approvedBakers(ctx context.Context, db *pgxpool.Pool) []bakerRow {
	rows, err := db.Query(ctx,
		`SELECT id, user_id, business_name FROM baker_profiles WHERE status='approved' ORDER BY created_at`)
	if err != nil {
		log.Fatalf("list bakers: %v", err)
	}
	defer rows.Close()
	var out []bakerRow
	for rows.Next() {
		var b bakerRow
		if err := rows.Scan(&b.id, &b.userID, &b.name); err != nil {
			log.Fatal(err)
		}
		out = append(out, b)
	}
	return out
}

func upsertProduct(ctx context.Context, db *pgxpool.Pool, b bakerRow, p seedProduct, catID map[string]string) {
	cid := catID[p.categorySlug]
	var nilable any = cid
	if cid == "" {
		nilable = nil
	}
	var occ, flv, fmt_ any
	if p.occasion != "" {
		occ, flv, fmt_ = p.occasion, p.flavor, p.format
	}
	var sub any
	if p.subcategory != "" {
		sub = p.subcategory
	}
	var disc any
	if p.onOffer {
		disc = p.discountPct
	}
	diet := p.dietary
	if diet == nil {
		diet = []string{} // column is NOT NULL DEFAULT '{}'
	}

	var pid string
	err := db.QueryRow(ctx,
		`INSERT INTO products
		  (baker_id, slug, category_id, title, description, base_price, lead_time_days, active,
		   subcategory_slug, dietary, is_custom, is_on_offer, discount_pct, rating_avg, rating_count,
		   cake_occasion, cake_flavor, cake_format, allow_custom_request)
		 VALUES ($1,$2,$3,$4,$5,$6,$7,true,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18)
		 ON CONFLICT (baker_id, slug) DO UPDATE SET
		   category_id=$3, title=$4, description=$5, base_price=$6, lead_time_days=$7, active=true,
		   subcategory_slug=$8, dietary=$9, is_custom=$10, is_on_offer=$11, discount_pct=$12,
		   rating_avg=$13, rating_count=$14, cake_occasion=$15, cake_flavor=$16, cake_format=$17,
		   allow_custom_request=$18, updated_at=now()
		 RETURNING id`,
		b.id, p.slug, nilable, p.title, p.desc, p.basePrice, p.lead,
		sub, diet, p.isCustom, p.onOffer, disc, p.ratingAvg, p.ratingCount,
		occ, flv, fmt_, p.allowCustom,
	).Scan(&pid)
	if err != nil {
		log.Fatalf("upsert product %s/%s: %v", b.name, p.slug, err)
	}

	// Replace sizes.
	if _, err := db.Exec(ctx, `DELETE FROM product_sizes WHERE product_id=$1`, pid); err != nil {
		log.Fatal(err)
	}
	for _, s := range p.sizes {
		var kg, serves any
		if s.weightKg > 0 {
			kg = s.weightKg
		}
		if s.serves > 0 {
			serves = s.serves
		}
		if _, err := db.Exec(ctx,
			`INSERT INTO product_sizes (product_id, label, weight_kg, serves, price) VALUES ($1,$2,$3,$4,$5)`,
			pid, s.label, kg, serves, s.price); err != nil {
			log.Fatal(err)
		}
	}

	// Replace images (media.s3_key holds the full URL for seeded products).
	if _, err := db.Exec(ctx, `DELETE FROM product_images WHERE product_id=$1`, pid); err != nil {
		log.Fatal(err)
	}
	for i, url := range p.images {
		var mid string
		if err := db.QueryRow(ctx,
			`INSERT INTO media (owner_id, kind, s3_key, status) VALUES ($1,'product',$2,'uploaded') RETURNING id`,
			b.userID, url).Scan(&mid); err != nil {
			log.Fatal(err)
		}
		if _, err := db.Exec(ctx,
			`INSERT INTO product_images (product_id, media_id, position) VALUES ($1,$2,$3)`,
			pid, mid, i); err != nil {
			log.Fatal(err)
		}
	}
}
