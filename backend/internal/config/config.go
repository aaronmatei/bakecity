package config

import (
	"os"
	"strconv"

	"github.com/joho/godotenv"
)

// Config holds all runtime configuration loaded from the environment.
type Config struct {
	Port string
	Env  string

	// PublicBaseURL is the device-reachable base URL of this API, used to build
	// local media blob URLs when no S3 is configured (e.g. http://host:8090).
	PublicBaseURL string

	DatabaseURL string
	RedisURL    string

	JWTSecret string

	AWSAccessKeyID     string
	AWSSecretAccessKey string
	AWSRegion          string
	AWSBucket          string
	// AWSEndpoint overrides the S3 endpoint for S3-compatible stores (e.g.
	// Cloudflare R2: https://<ACCOUNT_ID>.r2.cloudflarestorage.com). Empty
	// means real AWS S3.
	AWSEndpoint string

	PSPProvider  string
	PSPAPIKey    string
	PSPAPISecret string

	FCMServerKey string

	ATAPIKey   string
	ATUsername string

	AdminEmail string

	// Rate limiting (requests per minute per client IP).
	RateLimitPerMinute     int
	AuthRateLimitPerMinute int

	// Delivery auto-confirmation: once a baker submits proof, an out-for-delivery
	// order auto-confirms after AutoConfirmHours if the customer hasn't. The
	// background sweep runs every DeliverySweepSeconds.
	AutoConfirmHours     int
	DeliverySweepSeconds int
}

// Load reads configuration from a .env file (if present) and the environment,
// applying sane defaults for local development.
func Load() *Config {
	// Best-effort: ignore a missing .env file.
	_ = godotenv.Load()

	return &Config{
		Port: getEnv("PORT", "8080"),
		Env:  getEnv("ENV", "development"),

		PublicBaseURL: getEnv("PUBLIC_BASE_URL", "http://localhost:8090"),

		DatabaseURL: getEnv("DATABASE_URL", "postgres://postgres:password@localhost:5432/bakecity?sslmode=disable"),
		RedisURL:    getEnv("REDIS_URL", "redis://localhost:6379"),

		JWTSecret: getEnv("JWT_SECRET", "dev-insecure-secret-change-me"),

		AWSAccessKeyID:     getEnv("AWS_ACCESS_KEY_ID", ""),
		AWSSecretAccessKey: getEnv("AWS_SECRET_ACCESS_KEY", ""),
		AWSRegion:          getEnv("AWS_REGION", "us-east-1"),
		AWSBucket:          getEnv("AWS_BUCKET_NAME", "bakecity"),
		AWSEndpoint:        getEnv("S3_ENDPOINT", ""),

		PSPProvider:  getEnv("PSP_PROVIDER", "pesapal"),
		PSPAPIKey:    getEnv("PSP_API_KEY", ""),
		PSPAPISecret: getEnv("PSP_API_SECRET", ""),

		FCMServerKey: getEnv("FCM_SERVER_KEY", ""),

		ATAPIKey:   getEnv("AT_API_KEY", ""),
		ATUsername: getEnv("AT_USERNAME", ""),

		AdminEmail: getEnv("ADMIN_EMAIL", "admin@bakecity.local"),

		RateLimitPerMinute:     getEnvInt("RATE_LIMIT_PER_MINUTE", 120),
		AuthRateLimitPerMinute: getEnvInt("AUTH_RATE_LIMIT_PER_MINUTE", 10),

		AutoConfirmHours:     getEnvInt("DELIVERY_AUTO_CONFIRM_HOURS", 72),
		DeliverySweepSeconds: getEnvInt("DELIVERY_SWEEP_SECONDS", 900),
	}
}

// IsProduction reports whether the app runs in a production environment.
func (c *Config) IsProduction() bool {
	return c.Env == "production" || c.Env == "prod"
}

func getEnv(key, fallback string) string {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v, ok := os.LookupEnv(key); ok && v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}
