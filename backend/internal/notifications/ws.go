package notifications

import (
	"context"
	"encoding/json"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
	"github.com/redis/go-redis/v9"
)

const (
	// redisChannel is the shared pub/sub channel for cross-instance fan-out.
	redisChannel = "bakecity:notifications"

	writeWait  = 10 * time.Second
	pongWait   = 60 * time.Second
	pingPeriod = (pongWait * 9) / 10
	sendBuffer = 16
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	// Dev: allow any origin. Restrict to the app's origins in production.
	CheckOrigin: func(_ *http.Request) bool { return true },
}

// envelope is the pub/sub message: a per-user notification payload.
type envelope struct {
	UserID string          `json:"user_id"`
	Data   json.RawMessage `json:"data"`
}

// client is a single live WebSocket connection for a user.
type client struct {
	userID string
	conn   *websocket.Conn
	send   chan []byte
}

// Hub tracks live WebSocket connections per user and fans notifications out to
// them. With Redis it subscribes to a shared channel so an event delivered on
// any instance reaches that user's connections everywhere; without Redis it
// delivers in-process only (single-instance dev).
type Hub struct {
	mu    sync.RWMutex
	conns map[string]map[*client]struct{}
	rdb   *redis.Client
}

// NewHub constructs a Hub. If rdb is non-nil it starts a background subscriber
// for cross-instance delivery.
func NewHub(rdb *redis.Client) *Hub {
	h := &Hub{conns: make(map[string]map[*client]struct{}), rdb: rdb}
	if rdb != nil {
		go h.subscribe(context.Background())
	}
	return h
}

var _ Broadcaster = (*Hub)(nil)

func (h *Hub) add(c *client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if h.conns[c.userID] == nil {
		h.conns[c.userID] = make(map[*client]struct{})
	}
	h.conns[c.userID][c] = struct{}{}
}

func (h *Hub) remove(c *client) {
	h.mu.Lock()
	defer h.mu.Unlock()
	if set, ok := h.conns[c.userID]; ok {
		delete(set, c)
		if len(set) == 0 {
			delete(h.conns, c.userID)
		}
	}
}

// deliverLocal sends a message to a user's locally-connected clients. A client
// whose send buffer is full is skipped (it will catch up via the REST feed).
func (h *Hub) deliverLocal(userID string, msg []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for c := range h.conns[userID] {
		select {
		case c.send <- msg:
		default:
		}
	}
}

// Broadcast delivers a message to a user's connections. With Redis it publishes
// to the shared channel — every instance (including this one) delivers to its
// local connections when the subscriber receives it, so there is no double
// delivery. Without Redis it delivers locally.
func (h *Hub) Broadcast(ctx context.Context, userID string, msg []byte) {
	if h.rdb == nil {
		h.deliverLocal(userID, msg)
		return
	}
	env, err := json.Marshal(envelope{UserID: userID, Data: msg})
	if err != nil {
		return
	}
	if err := h.rdb.Publish(ctx, redisChannel, env).Err(); err != nil {
		log.Printf("ws: publish failed, delivering locally: %v", err)
		h.deliverLocal(userID, msg)
	}
}

func (h *Hub) subscribe(ctx context.Context) {
	sub := h.rdb.Subscribe(ctx, redisChannel)
	defer func() { _ = sub.Close() }()
	for msg := range sub.Channel() {
		var env envelope
		if err := json.Unmarshal([]byte(msg.Payload), &env); err != nil {
			continue
		}
		h.deliverLocal(env.UserID, env.Data)
	}
}

// Serve upgrades an HTTP request to a WebSocket for userID and pumps
// notifications to it until the connection closes. It blocks for the lifetime
// of the connection.
func (h *Hub) Serve(w http.ResponseWriter, r *http.Request, userID string) error {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		return err
	}
	c := &client{userID: userID, conn: conn, send: make(chan []byte, sendBuffer)}
	h.add(c)
	go c.writePump()
	c.readPump(h) // blocks until the connection closes
	return nil
}

// readPump drains inbound frames (we expect none beyond pings/close) and tears
// down the connection on error. It removes the client from the hub before
// closing its send channel, so deliverLocal can never send on a closed channel.
func (c *client) readPump(h *Hub) {
	defer func() {
		h.remove(c)
		_ = c.conn.Close()
		close(c.send)
	}()
	c.conn.SetReadLimit(512)
	_ = c.conn.SetReadDeadline(time.Now().Add(pongWait))
	c.conn.SetPongHandler(func(string) error {
		return c.conn.SetReadDeadline(time.Now().Add(pongWait))
	})
	for {
		if _, _, err := c.conn.ReadMessage(); err != nil {
			return
		}
	}
}

// writePump writes queued messages and periodic pings to the connection.
func (c *client) writePump() {
	ticker := time.NewTicker(pingPeriod)
	defer ticker.Stop()
	for {
		select {
		case msg, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, msg); err != nil {
				return
			}
		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(writeWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
