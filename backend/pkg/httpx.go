package pkg

import (
	"net/http"

	"github.com/gin-gonic/gin"
)

// OK writes a 200 response with the given payload.
func OK(c *gin.Context, data any) {
	c.JSON(http.StatusOK, data)
}

// Created writes a 201 response with the given payload.
func Created(c *gin.Context, data any) {
	c.JSON(http.StatusCreated, data)
}

// NoContent writes a 204 response.
func NoContent(c *gin.Context) {
	c.Status(http.StatusNoContent)
}

// Error writes a structured error response and aborts the request.
func Error(c *gin.Context, status int, code, msg string) {
	c.AbortWithStatusJSON(status, NewErrorResponse(code, msg))
}

// FromAPIError writes an APIError as a structured response.
func FromAPIError(c *gin.Context, e *APIError) {
	Error(c, e.Status, e.Code, e.Message)
}

// NotImplemented writes a standard 501 response for scaffold handlers.
func NotImplemented(c *gin.Context) {
	Error(c, http.StatusNotImplemented, ErrCodeNotImplemented, "endpoint not implemented")
}
