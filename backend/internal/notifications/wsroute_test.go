package notifications

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/gorilla/websocket"

	"github.com/corebalt/bakecity/internal/middleware"
)

const testSecret = "test-secret"

func signToken(t *testing.T, userID string) string {
	t.Helper()
	claims := &middleware.AuthClaims{
		RoleMask:         middleware.RoleCustomer,
		RegisteredClaims: jwt.RegisteredClaims{Subject: userID},
	}
	s, err := jwt.NewWithClaims(jwt.SigningMethodHS256, claims).SignedString([]byte(testSecret))
	if err != nil {
		t.Fatalf("sign: %v", err)
	}
	return s
}

// testRouter builds a minimal gin engine with just the notification WS route.
func testRouter(hub *Hub) http.Handler {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	h := NewHandler(NewService(NewRepository(nil), NewStubSender(), hub), hub, testSecret)
	h.RegisterPublicRoutes(r.Group("/api/v1"))
	return r
}

func TestServeWSRejectsBadToken(t *testing.T) {
	srv := httptest.NewServer(testRouter(NewHub(nil)))
	defer srv.Close()

	url := "ws" + strings.TrimPrefix(srv.URL, "http") + "/api/v1/ws/notifications?token=garbage"
	_, resp, err := websocket.DefaultDialer.Dial(url, nil)
	if err == nil {
		t.Fatal("expected handshake to fail with a bad token")
	}
	if resp == nil || resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("want 401, got %v", resp)
	}
}

func TestServeWSAuthenticatesAndStreams(t *testing.T) {
	hub := NewHub(nil)
	srv := httptest.NewServer(testRouter(hub))
	defer srv.Close()

	token := signToken(t, "user-42")
	url := "ws" + strings.TrimPrefix(srv.URL, "http") + "/api/v1/ws/notifications?token=" + token
	conn, resp, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		t.Fatalf("dial (status %v): %v", resp, err)
	}
	defer conn.Close()

	// Wait for registration, then broadcast and read it back.
	deadline := time.Now().Add(2 * time.Second)
	for {
		hub.mu.RLock()
		n := len(hub.conns["user-42"])
		hub.mu.RUnlock()
		if n == 1 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("connection not registered")
		}
		time.Sleep(5 * time.Millisecond)
	}

	want := []byte(`{"type":"payout_sent"}`)
	hub.Broadcast(t.Context(), "user-42", want)

	_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	_, got, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if string(got) != string(want) {
		t.Fatalf("got %q, want %q", got, want)
	}
}
