package orders

// Order status values forming the order state machine.
const (
	StatusDraft          = "DRAFT"
	StatusQuoteRequested = "QUOTE_REQUESTED"
	StatusNegotiating    = "NEGOTIATING"
	StatusQuoted         = "QUOTED"
	StatusApproved       = "APPROVED"
	StatusDepositPending = "DEPOSIT_PENDING"
	StatusDepositPaid    = "DEPOSIT_PAID"
	StatusInProduction   = "IN_PRODUCTION"
	StatusReady          = "READY"
	StatusOutForDelivery = "OUT_FOR_DELIVERY"
	StatusDelivered      = "DELIVERED"
	StatusCompleted      = "COMPLETED"
	StatusCancelled      = "CANCELLED"
	StatusDisputed       = "DISPUTED"
	StatusRefunded       = "REFUNDED"
)

// allowedTransitions encodes the valid order state transitions.
var allowedTransitions = map[string][]string{
	StatusDraft:          {StatusQuoteRequested, StatusCancelled},
	StatusQuoteRequested: {StatusNegotiating, StatusQuoted, StatusCancelled},
	StatusNegotiating:    {StatusQuoted, StatusCancelled},
	StatusQuoted:         {StatusNegotiating, StatusApproved, StatusCancelled},
	StatusApproved:       {StatusDepositPending, StatusCancelled},
	StatusDepositPending: {StatusDepositPaid, StatusCancelled},
	StatusDepositPaid:    {StatusInProduction, StatusDisputed, StatusCancelled},
	StatusInProduction:   {StatusReady, StatusDisputed, StatusCancelled},
	StatusReady:          {StatusOutForDelivery, StatusDisputed, StatusCancelled},
	StatusOutForDelivery: {StatusDelivered, StatusDisputed, StatusCancelled},
	StatusDelivered:      {StatusCompleted, StatusDisputed},
	StatusCompleted:      {},
	StatusCancelled:      {StatusRefunded},
	StatusDisputed:       {StatusRefunded, StatusCompleted, StatusCancelled},
	StatusRefunded:       {},
}

// CanTransition reports whether moving from one status to another is allowed.
func CanTransition(from, to string) bool {
	for _, next := range allowedTransitions[from] {
		if next == to {
			return true
		}
	}
	return false
}

// IsTerminal reports whether a status has no outgoing transitions.
func IsTerminal(status string) bool {
	return len(allowedTransitions[status]) == 0
}
