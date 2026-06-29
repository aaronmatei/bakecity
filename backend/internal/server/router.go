// Package server wires the dependency graph and HTTP router.
package server

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"

	"github.com/corebalt/bakecity/internal/admin"
	"github.com/corebalt/bakecity/internal/analytics"
	"github.com/corebalt/bakecity/internal/auth"
	"github.com/corebalt/bakecity/internal/bakers"
	"github.com/corebalt/bakecity/internal/catalog"
	"github.com/corebalt/bakecity/internal/config"
	"github.com/corebalt/bakecity/internal/delivery"
	"github.com/corebalt/bakecity/internal/disputes"
	"github.com/corebalt/bakecity/internal/ledger"
	"github.com/corebalt/bakecity/internal/media"
	"github.com/corebalt/bakecity/internal/messaging"
	"github.com/corebalt/bakecity/internal/middleware"
	"github.com/corebalt/bakecity/internal/notifications"
	"github.com/corebalt/bakecity/internal/orders"
	"github.com/corebalt/bakecity/internal/payments"
	"github.com/corebalt/bakecity/internal/production"
	"github.com/corebalt/bakecity/internal/quotes"
	"github.com/corebalt/bakecity/internal/reviews"
	"github.com/corebalt/bakecity/internal/search"
	"github.com/corebalt/bakecity/internal/users"
	"github.com/corebalt/bakecity/pkg"
	"github.com/corebalt/bakecity/pkg/pspclient"
	"github.com/corebalt/bakecity/pkg/storage"
)

// Deps carries the external dependencies handed to the router.
type Deps struct {
	Cfg   *config.Config
	DB    *pgxpool.Pool // may be nil in degraded dev mode
	Redis *redis.Client // may be nil in degraded dev mode
}

// devCORS reflects the request Origin and answers preflight requests, allowing
// a browser-based client to call the API during development. It echoes the
// Origin (rather than "*") so credentialed requests are permitted.
func devCORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		if origin == "" {
			origin = "*"
		}
		c.Header("Access-Control-Allow-Origin", origin)
		c.Header("Access-Control-Allow-Credentials", "true")
		c.Header("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Requested-With")
		c.Header("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}
		c.Next()
	}
}

// New builds the Gin engine, constructs the domain dependency graph, and mounts
// all routes under /api/v1.
func New(deps Deps) *gin.Engine {
	if deps.Cfg.IsProduction() {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()
	r.Use(middleware.Recovery(), middleware.RequestID(), middleware.Logger())

	// Dev-only permissive CORS so a browser-served build (Flutter web /
	// device_preview) can call the API. Disabled in production.
	if !deps.Cfg.IsProduction() {
		r.Use(devCORS())
	}

	r.GET("/health", func(c *gin.Context) {
		pkg.OK(c, gin.H{"status": "ok"})
	})

	// Shared infrastructure.
	psp := pspclient.NewStubClient()
	// Use a real S3-compatible presigner (AWS S3 / Cloudflare R2 / MinIO) when
	// credentials are configured; otherwise fall back to the dev stub that
	// signs nothing.
	var presigner storage.Presigner
	if deps.Cfg.AWSAccessKeyID != "" && deps.Cfg.AWSSecretAccessKey != "" {
		presigner = storage.NewS3Presigner(
			deps.Cfg.AWSEndpoint, deps.Cfg.AWSRegion, deps.Cfg.AWSBucket,
			deps.Cfg.AWSAccessKeyID, deps.Cfg.AWSSecretAccessKey,
		)
	} else if deps.DB != nil {
		// No S3 configured: store and serve media bytes from the API itself so
		// the upload flow works in development. Blob routes are public.
		presigner = storage.NewLocalPresigner(deps.Cfg.PublicBaseURL)
		media.NewBlobStore(deps.DB).RegisterRoutes(r)
	} else {
		presigner = storage.NewStubPresigner(deps.Cfg.AWSBucket, deps.Cfg.AWSRegion)
	}
	sender := notifications.NewStubSender()
	hub := notifications.NewHub(deps.Redis)
	idem := pkg.NewIdempotencyStore(deps.Redis, 0)
	limiter := pkg.NewRateLimiter(deps.Redis)

	// Repositories.
	authRepo := auth.NewRepository(deps.DB)
	usersRepo := users.NewRepository(deps.DB)
	bakersRepo := bakers.NewRepository(deps.DB)
	catalogRepo := catalog.NewRepository(deps.DB)
	searchRepo := search.NewRepository(deps.DB)
	ordersRepo := orders.NewRepository(deps.DB)
	quotesRepo := quotes.NewRepository(deps.DB)
	messagingRepo := messaging.NewRepository(deps.DB)
	productionRepo := production.NewRepository(deps.DB)
	mediaRepo := media.NewRepository(deps.DB)
	deliveryRepo := delivery.NewRepository(deps.DB)
	paymentsRepo := payments.NewRepository(deps.DB)
	ledgerRepo := ledger.NewRepository(deps.DB)
	disputesRepo := disputes.NewRepository(deps.DB)
	reviewsRepo := reviews.NewRepository(deps.DB)
	notificationsRepo := notifications.NewRepository(deps.DB)
	adminRepo := admin.NewRepository(deps.DB)
	analyticsRepo := analytics.NewRepository(deps.DB)

	// Services.
	authSvc := auth.NewService(authRepo, deps.Cfg.JWTSecret)
	usersSvc := users.NewService(usersRepo)
	catalogSvc := catalog.NewService(catalogRepo)
	searchSvc := search.NewService(searchRepo)
	notificationsSvc := notifications.NewService(notificationsRepo, sender, hub)
	ledgerSvc := ledger.NewService(ledgerRepo)
	ordersSvc := orders.NewService(ordersRepo, ledgerSvc, notificationsSvc)
	quotesSvc := quotes.NewService(quotesRepo, ordersSvc, notificationsSvc)
	messagingSvc := messaging.NewService(messagingRepo, ordersSvc)
	productionSvc := production.NewService(productionRepo, ordersSvc, notificationsSvc)
	mediaSvc := media.NewService(mediaRepo, presigner, ordersSvc)
	// Bakers depends on media to store/read KYC identity documents, so it is
	// constructed after mediaSvc.
	bakersSvc := bakers.NewService(bakersRepo, mediaSvc)
	deliverySvc := delivery.NewService(deliveryRepo, ordersSvc, notificationsSvc)
	paymentsSvc := payments.NewService(paymentsRepo, psp, idem, ledgerSvc, ordersSvc, notificationsSvc)
	disputesSvc := disputes.NewService(disputesRepo, ordersSvc, ledgerSvc, notificationsSvc)
	reviewsSvc := reviews.NewService(reviewsRepo, ordersSvc)
	adminSvc := admin.NewService(adminRepo, ordersSvc, ledgerSvc, disputesSvc)
	analyticsSvc := analytics.NewService(analyticsRepo)

	// Handlers.
	authH := auth.NewHandler(authSvc)
	usersH := users.NewHandler(usersSvc)
	bakersH := bakers.NewHandler(bakersSvc)
	catalogH := catalog.NewHandler(catalogSvc)
	searchH := search.NewHandler(searchSvc)
	ordersH := orders.NewHandler(ordersSvc)
	quotesH := quotes.NewHandler(quotesSvc)
	messagingH := messaging.NewHandler(messagingSvc)
	productionH := production.NewHandler(productionSvc)
	mediaH := media.NewHandler(mediaSvc)
	deliveryH := delivery.NewHandler(deliverySvc)
	paymentsH := payments.NewHandler(paymentsSvc)
	disputesH := disputes.NewHandler(disputesSvc)
	reviewsH := reviews.NewHandler(reviewsSvc)
	notificationsH := notifications.NewHandler(notificationsSvc, hub, deps.Cfg.JWTSecret)
	adminH := admin.NewHandler(adminSvc)
	analyticsH := analytics.NewHandler(analyticsSvc)

	api := r.Group("/api/v1")
	// Global per-IP rate limit across the whole API (fails open without Redis).
	api.Use(middleware.RateLimit(limiter, "ip", deps.Cfg.RateLimitPerMinute, time.Minute, middleware.ClientIP))

	// Auth endpoints get a stricter per-IP limit to blunt credential stuffing.
	authGrp := api.Group("")
	authGrp.Use(middleware.RateLimit(limiter, "auth", deps.Cfg.AuthRateLimitPerMinute, time.Minute, middleware.ClientIP))
	authH.RegisterRoutes(authGrp)

	// Public routes (no auth).
	public := api.Group("")
	searchH.RegisterRoutes(public)
	catalogH.RegisterPublicRoutes(public)       // browse products/categories
	paymentsH.RegisterPublicRoutes(public)      // PSP webhook (signature-verified)
	notificationsH.RegisterPublicRoutes(public) // WebSocket (token in query param)

	// Authenticated routes (JWT bearer).
	authed := api.Group("")
	authed.Use(middleware.Auth(deps.Cfg.JWTSecret))
	usersH.RegisterRoutes(authed)
	bakersH.RegisterRoutes(authed)
	catalogH.RegisterRoutes(authed)
	ordersH.RegisterRoutes(authed)
	quotesH.RegisterRoutes(authed)
	messagingH.RegisterRoutes(authed)
	productionH.RegisterRoutes(authed)
	mediaH.RegisterRoutes(authed)
	deliveryH.RegisterRoutes(authed)
	paymentsH.RegisterRoutes(authed)
	disputesH.RegisterRoutes(authed)
	reviewsH.RegisterRoutes(authed)
	notificationsH.RegisterRoutes(authed)

	// Admin routes (JWT bearer + admin role).
	adminGrp := api.Group("")
	adminGrp.Use(middleware.Auth(deps.Cfg.JWTSecret), middleware.RequireRole(middleware.RoleAdmin))
	adminH.RegisterRoutes(adminGrp)
	analyticsH.RegisterRoutes(adminGrp)

	// Fallback for unknown routes.
	r.NoRoute(func(c *gin.Context) {
		pkg.Error(c, http.StatusNotFound, pkg.ErrCodeNotFound, "route not found")
	})

	return r
}
