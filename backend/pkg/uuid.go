package pkg

import "github.com/google/uuid"

// GenerateID creates a new UUID
func GenerateID() string {
	return uuid.New().String()
}

// IsValidUUID checks if a string is a valid UUID
func IsValidUUID(id string) bool {
	_, err := uuid.Parse(id)
	return err == nil
}
