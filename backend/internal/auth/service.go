package auth

import (
	"context"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"

	"github.com/corebalt/bakecity/internal/middleware"
	"github.com/corebalt/bakecity/pkg"
)

// tokenTTL is the lifetime of issued access tokens.
const tokenTTL = 72 * time.Hour

// Service implements authentication business logic.
type Service struct {
	repo      *Repository
	jwtSecret string
}

// NewService constructs a Service.
func NewService(repo *Repository, jwtSecret string) *Service {
	return &Service{repo: repo, jwtSecret: jwtSecret}
}

// Register creates a new user, hashing the password and issuing a token.
func (s *Service) Register(ctx context.Context, req RegisterRequest) (*AuthResponse, error) {
	phone := pkg.NormalizePhone(req.Phone)
	if !pkg.IsValidPhone(phone) {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "invalid phone number")
	}
	if req.Email != "" && !pkg.IsValidEmail(req.Email) {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "invalid email")
	}

	roleMask := roleMaskFor(req.Role)

	// Bakers must supply a bakery name at sign-up; it seeds their baker profile.
	// For non-bakers the field is ignored so no profile is created.
	businessName := strings.TrimSpace(req.BusinessName)
	if roleMask&middleware.RoleBaker != 0 {
		if businessName == "" {
			return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "bakery name is required")
		}
	} else {
		businessName = ""
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, pkg.NewAPIError(http.StatusInternalServerError, pkg.ErrCodeInternal, "could not hash password").WithErr(err)
	}

	userID, err := s.repo.CreateUser(ctx, phone, req.Email, string(hash), roleMask, businessName)
	if err != nil {
		if errors.Is(err, pkg.ErrNotImplemented) {
			return nil, pkg.NewAPIError(http.StatusNotImplemented, pkg.ErrCodeNotImplemented, "auth storage not configured")
		}
		return nil, pkg.NewAPIError(http.StatusConflict, pkg.ErrCodeConflict, "could not create user").WithErr(err)
	}

	return s.issue(userID, roleMask)
}

// Login verifies credentials and issues a token.
func (s *Service) Login(ctx context.Context, req LoginRequest) (*AuthResponse, error) {
	identifier := strings.TrimSpace(req.Identifier)
	if strings.Contains(identifier, "@") {
		identifier = strings.ToLower(identifier)
	} else {
		identifier = pkg.NormalizePhone(identifier)
	}

	cred, err := s.repo.GetCredentialByIdentifier(ctx, identifier)
	if err != nil {
		if errors.Is(err, pkg.ErrNotImplemented) {
			return nil, pkg.NewAPIError(http.StatusNotImplemented, pkg.ErrCodeNotImplemented, "auth storage not configured")
		}
		return nil, pkg.NewAPIError(http.StatusUnauthorized, pkg.ErrCodeUnauthorized, "invalid credentials")
	}

	if err := bcrypt.CompareHashAndPassword([]byte(cred.PasswordHash), []byte(req.Password)); err != nil {
		return nil, pkg.NewAPIError(http.StatusUnauthorized, pkg.ErrCodeUnauthorized, "invalid credentials")
	}

	return s.issue(cred.UserID, cred.RoleMask)
}

// issue signs a JWT for the user.
func (s *Service) issue(userID string, roleMask int) (*AuthResponse, error) {
	token, expiresAt, err := s.IssueToken(userID, roleMask)
	if err != nil {
		return nil, pkg.NewAPIError(http.StatusInternalServerError, pkg.ErrCodeInternal, "could not issue token").WithErr(err)
	}
	return &AuthResponse{
		UserID:    userID,
		Token:     token,
		RoleMask:  roleMask,
		ExpiresAt: expiresAt,
	}, nil
}

// IssueToken signs an HS256 JWT carrying the user id and role mask.
func (s *Service) IssueToken(userID string, roleMask int) (string, time.Time, error) {
	expiresAt := time.Now().Add(tokenTTL)
	claims := middleware.AuthClaims{
		RoleMask: roleMask,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			IssuedAt:  jwt.NewNumericDate(time.Now()),
			ExpiresAt: jwt.NewNumericDate(expiresAt),
		},
	}
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(s.jwtSecret))
	if err != nil {
		return "", time.Time{}, err
	}
	return signed, expiresAt, nil
}

func roleMaskFor(role string) int {
	switch strings.ToLower(strings.TrimSpace(role)) {
	case "baker":
		return middleware.RoleBaker
	default:
		return middleware.RoleCustomer
	}
}
