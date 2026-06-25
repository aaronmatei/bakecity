package main

import (
	"context"
	"errors"
	"log"
	"net/http"
	"os/signal"
	"syscall"
	"time"

	"github.com/corebalt/bakecity/internal/config"
	"github.com/corebalt/bakecity/internal/platform/cache"
	"github.com/corebalt/bakecity/internal/platform/database"
	"github.com/corebalt/bakecity/internal/server"
)

func main() {
	cfg := config.Load()

	// Root context cancelled on SIGINT/SIGTERM for graceful shutdown.
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	// Connect Postgres. Log-and-continue so the scaffold still boots for dev.
	connectCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
	pool, err := database.NewPool(connectCtx, cfg.DatabaseURL)
	cancel()
	if err != nil {
		log.Printf("warning: database unavailable, continuing in degraded mode: %v", err)
	} else {
		defer pool.Close()
		log.Println("connected to postgres")
	}

	// Connect Redis (best-effort).
	connectCtx, cancel = context.WithTimeout(ctx, 5*time.Second)
	rdb, err := cache.NewClient(connectCtx, cfg.RedisURL)
	cancel()
	if err != nil {
		log.Printf("warning: redis unavailable, continuing in degraded mode: %v", err)
	} else {
		defer func() { _ = rdb.Close() }()
		log.Println("connected to redis")
	}

	router := server.New(server.Deps{Cfg: cfg, DB: pool, Redis: rdb})

	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           router,
		ReadHeaderTimeout: 10 * time.Second,
	}

	go func() {
		log.Printf("BakeCity API listening on :%s (env=%s)", cfg.Port, cfg.Env)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("server error: %v", err)
		}
	}()

	<-ctx.Done()
	log.Println("shutdown signal received")

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer shutdownCancel()
	if err := srv.Shutdown(shutdownCtx); err != nil {
		log.Printf("graceful shutdown failed: %v", err)
	}
	log.Println("server stopped")
}
