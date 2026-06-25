// Package server wires the dependency graph and HTTP router.
package server

import (
	"net/http"

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
)

// Deps carries the external dependencies handed to the router.
type Deps struct {
	Cfg   *config.Config
	DB    *pgxpool.Pool // may be nil in degraded dev mode
	Redis *redis.Client // may be nil in degraded dev mode
}

// New builds the Gin engine, constructs the domain dependency graph, and mounts
// all routes under /api/v1.
func New(deps Deps) *gin.Engine {
	if deps.Cfg.IsProduction() {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.New()
	r.Use(middleware.Recovery(), middleware.RequestID(), middleware.Logger())

	r.GET("/health", func(c *gin.Context) {
		pkg.OK(c, gin.H{"status": "ok"})
	})

	// Shared infrastructure.
	psp := pspclient.NewStubClient()
	idem := pkg.NewIdempotencyStore(deps.Redis, 0)

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
	bakersSvc := bakers.NewService(bakersRepo)
	catalogSvc := catalog.NewService(catalogRepo)
	searchSvc := search.NewService(searchRepo)
	ordersSvc := orders.NewService(ordersRepo)
	quotesSvc := quotes.NewService(quotesRepo)
	messagingSvc := messaging.NewService(messagingRepo)
	productionSvc := production.NewService(productionRepo)
	mediaSvc := media.NewService(mediaRepo)
	deliverySvc := delivery.NewService(deliveryRepo)
	ledgerSvc := ledger.NewService(ledgerRepo)
	paymentsSvc := payments.NewService(paymentsRepo, psp, idem)
	disputesSvc := disputes.NewService(disputesRepo)
	reviewsSvc := reviews.NewService(reviewsRepo)
	notificationsSvc := notifications.NewService(notificationsRepo)
	adminSvc := admin.NewService(adminRepo)
	analyticsSvc := analytics.NewService(analyticsRepo)
	_ = ledgerSvc // internal accounting module; not directly HTTP-mounted

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
	notificationsH := notifications.NewHandler(notificationsSvc)
	adminH := admin.NewHandler(adminSvc)
	analyticsH := analytics.NewHandler(analyticsSvc)

	api := r.Group("/api/v1")

	// Public routes (no auth).
	public := api.Group("")
	authH.RegisterRoutes(public)
	searchH.RegisterRoutes(public)
	catalogH.RegisterPublicRoutes(public)  // browse products/categories
	paymentsH.RegisterPublicRoutes(public) // PSP webhook (signature-verified)

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
