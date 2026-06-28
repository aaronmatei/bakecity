package delivery

import "testing"

func TestIsValidMethod(t *testing.T) {
	valid := []string{MethodOwn, MethodCourier, MethodPickup, MethodSelf}
	for _, m := range valid {
		if !IsValidMethod(m) {
			t.Errorf("IsValidMethod(%q) = false, want true", m)
		}
	}
	invalid := []string{"", "drone", "teleport", "OWN"}
	for _, m := range invalid {
		if IsValidMethod(m) {
			t.Errorf("IsValidMethod(%q) = true, want false", m)
		}
	}
}
