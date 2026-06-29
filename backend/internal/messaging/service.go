package messaging

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/corebalt/bakecity/internal/orders"
	"github.com/corebalt/bakecity/pkg"
)

// Actor identifies the authenticated caller for authorization checks.
type Actor struct {
	UserID  string
	IsAdmin bool
}

// Service implements messaging business logic. It uses the orders service to
// resolve participants for authorization.
type Service struct {
	repo   *Repository
	orders *orders.Service
}

// NewService constructs a Service.
func NewService(repo *Repository, ordersSvc *orders.Service) *Service {
	return &Service{repo: repo, orders: ordersSvc}
}

// Send posts a message to an order's thread (created on first use). Only the
// order's customer, baker, or an admin may post.
func (s *Service) Send(ctx context.Context, actor Actor, orderID string, req SendMessageRequest) (*Message, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if err := s.authorize(ctx, actor, order); err != nil {
		return nil, err
	}
	if strings.TrimSpace(req.Body) == "" && req.MediaID == "" {
		return nil, pkg.NewAPIError(http.StatusBadRequest, pkg.ErrCodeValidation, "message must have a body or media")
	}
	threadID, err := s.repo.ThreadForOrder(ctx, orderID)
	if err != nil {
		return nil, err
	}
	return s.repo.Insert(ctx, threadID, actor.UserID, req.Body, req.MediaID)
}

// List returns an order's messages chronologically; participants and admins
// only. An order with no thread yet returns an empty list.
func (s *Service) List(ctx context.Context, actor Actor, orderID string, limit, offset int) ([]Message, error) {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return nil, err
	}
	if err := s.authorize(ctx, actor, order); err != nil {
		return nil, err
	}
	threadID, err := s.repo.ThreadIDByOrder(ctx, orderID)
	if errors.Is(err, pkg.ErrNotFound) {
		return []Message{}, nil
	}
	if err != nil {
		return nil, err
	}
	return s.repo.List(ctx, threadID, limit, offset)
}

// MarkRead stamps the counterparty's messages in an order's thread as read.
// Unlike List, marking is an explicit action the client invokes once the
// messages are actually on screen, so read receipts reflect real reads rather
// than every poll/open. Participants and admins only; no thread yet is a no-op.
func (s *Service) MarkRead(ctx context.Context, actor Actor, orderID string) error {
	order, err := s.orders.OrderByID(ctx, orderID)
	if err != nil {
		return err
	}
	if err := s.authorize(ctx, actor, order); err != nil {
		return err
	}
	threadID, err := s.repo.ThreadIDByOrder(ctx, orderID)
	if errors.Is(err, pkg.ErrNotFound) {
		return nil
	}
	if err != nil {
		return err
	}
	return s.repo.MarkThreadRead(ctx, threadID, actor.UserID)
}

// authorize permits the order's customer, its baker, or an admin.
func (s *Service) authorize(ctx context.Context, actor Actor, order *orders.Order) error {
	if actor.IsAdmin || order.CustomerID == actor.UserID {
		return nil
	}
	bakerUserID, err := s.orders.BakerUserID(ctx, order.BakerID)
	if err == nil && bakerUserID == actor.UserID {
		return nil
	}
	return pkg.NewAPIError(http.StatusForbidden, pkg.ErrCodeForbidden, "not a participant in this order")
}
