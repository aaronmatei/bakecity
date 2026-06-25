package admin

// Service implements admin business logic (moderation, dispute resolution,
// refunds). It coordinates across other domains' services in a full build.
type Service struct {
	repo *Repository
}

// NewService constructs a Service.
func NewService(repo *Repository) *Service {
	return &Service{repo: repo}
}
