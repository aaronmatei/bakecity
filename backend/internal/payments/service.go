package payments

import (
	"github.com/corebalt/bakecity/pkg"
	"github.com/corebalt/bakecity/pkg/pspclient"
)

// Service implements payment business logic: escrow collection, balance
// settlement, refunds, and webhook reconciliation against the PSP.
type Service struct {
	repo *Repository
	psp  pspclient.PSPClient
	idem *pkg.IdempotencyStore
}

// NewService constructs a Service.
func NewService(repo *Repository, psp pspclient.PSPClient, idem *pkg.IdempotencyStore) *Service {
	return &Service{repo: repo, psp: psp, idem: idem}
}
