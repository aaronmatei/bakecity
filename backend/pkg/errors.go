package pkg

import (
	"encoding/json"
	"errors"
	"fmt"
)

// ErrorResponse is a standard error response format
type ErrorResponse struct {
	Code    string `json:"code"`
	Message string `json:"message"`
	Details any    `json:"details,omitempty"`
}

// NewErrorResponse creates a new error response
func NewErrorResponse(code, message string) ErrorResponse {
	return ErrorResponse{
		Code:    code,
		Message: message,
	}
}

// String returns JSON representation
func (e ErrorResponse) String() string {
	b, _ := json.Marshal(e)
	return string(b)
}

// Common error codes
const (
	ErrCodeBadRequest     = "BAD_REQUEST"
	ErrCodeUnauthorized   = "UNAUTHORIZED"
	ErrCodeForbidden      = "FORBIDDEN"
	ErrCodeNotFound       = "NOT_FOUND"
	ErrCodeConflict       = "CONFLICT"
	ErrCodeInternal       = "INTERNAL_ERROR"
	ErrCodeValidation     = "VALIDATION_ERROR"
	ErrCodeNotImplemented = "NOT_IMPLEMENTED"
)

// APIError is a typed error carrying an HTTP status and a machine-readable code.
type APIError struct {
	Status  int    `json:"-"`
	Code    string `json:"code"`
	Message string `json:"message"`
	Err     error  `json:"-"`
}

func (e *APIError) Error() string {
	if e.Err != nil {
		return fmt.Sprintf("%s: %s: %v", e.Code, e.Message, e.Err)
	}
	return fmt.Sprintf("%s: %s", e.Code, e.Message)
}

func (e *APIError) Unwrap() error { return e.Err }

// NewAPIError constructs an APIError.
func NewAPIError(status int, code, message string) *APIError {
	return &APIError{Status: status, Code: code, Message: message}
}

// WithErr attaches an underlying error to the APIError and returns it.
func (e *APIError) WithErr(err error) *APIError {
	e.Err = err
	return e
}

// Sentinel errors used across the codebase.
var (
	// ErrNotImplemented is returned by scaffold method stubs.
	ErrNotImplemented = errors.New("not implemented")
	// ErrNotFound indicates a missing resource at the repository layer.
	ErrNotFound = errors.New("not found")
	// ErrConflict indicates a uniqueness or state conflict.
	ErrConflict = errors.New("conflict")
)
