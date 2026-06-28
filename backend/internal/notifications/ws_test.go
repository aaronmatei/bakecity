package notifications

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/gorilla/websocket"
)

// TestHubDeliversToConnectedClient exercises the full local path: upgrade a
// connection for a user, Broadcast to that user, and assert the bytes arrive.
func TestHubDeliversToConnectedClient(t *testing.T) {
	hub := NewHub(nil) // no Redis: in-process delivery

	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_ = hub.Serve(w, r, "user-1")
	}))
	defer srv.Close()

	url := "ws" + strings.TrimPrefix(srv.URL, "http")
	conn, _, err := websocket.DefaultDialer.Dial(url, nil)
	if err != nil {
		t.Fatalf("dial: %v", err)
	}
	defer conn.Close()

	// Give the server a moment to register the connection in the hub.
	deadline := time.Now().Add(2 * time.Second)
	for {
		hub.mu.RLock()
		n := len(hub.conns["user-1"])
		hub.mu.RUnlock()
		if n == 1 {
			break
		}
		if time.Now().After(deadline) {
			t.Fatal("connection was never registered in the hub")
		}
		time.Sleep(5 * time.Millisecond)
	}

	want := []byte(`{"type":"deposit_confirmed"}`)
	hub.Broadcast(context.Background(), "user-1", want)

	_ = conn.SetReadDeadline(time.Now().Add(2 * time.Second))
	_, got, err := conn.ReadMessage()
	if err != nil {
		t.Fatalf("read: %v", err)
	}
	if string(got) != string(want) {
		t.Fatalf("got %q, want %q", got, want)
	}
}

// TestHubBroadcastToUnknownUserIsNoop ensures broadcasting to a user with no
// connections does not panic or block.
func TestHubBroadcastToUnknownUserIsNoop(t *testing.T) {
	hub := NewHub(nil)
	hub.Broadcast(context.Background(), "nobody", []byte(`{}`))
}
