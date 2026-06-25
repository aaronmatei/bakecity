package pkg

import (
	"regexp"
	"strings"
)

var (
	emailRe = regexp.MustCompile(`^[^@\s]+@[^@\s]+\.[^@\s]+$`)
	// Kenyan / international phone in E.164-ish form: optional +, 9-15 digits.
	phoneRe = regexp.MustCompile(`^\+?[0-9]{9,15}$`)
)

// IsValidEmail reports whether s looks like a valid email address.
func IsValidEmail(s string) bool {
	return emailRe.MatchString(strings.TrimSpace(s))
}

// IsValidPhone reports whether s looks like a valid phone number.
func IsValidPhone(s string) bool {
	return phoneRe.MatchString(strings.TrimSpace(s))
}

// NormalizePhone trims spaces and common separators from a phone number.
func NormalizePhone(s string) string {
	r := strings.NewReplacer(" ", "", "-", "", "(", "", ")", "")
	return r.Replace(strings.TrimSpace(s))
}
