package media

import (
	"errors"
	"io"
	"net/http"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// maxBlobBytes caps a single uploaded blob (25 MiB) for local dev storage.
const maxBlobBytes = 25 << 20

// BlobStore serves the local-development media store: it accepts raw uploads and
// serves them back, backed by the media_blobs table. The routes are PUBLIC (no
// auth): uploads come from a bare client that bypasses API auth headers, and
// downloads are loaded directly by <img>/image widgets. Used only when no S3 is
// configured (see storage.LocalPresigner).
type BlobStore struct {
	db *pgxpool.Pool
}

// NewBlobStore constructs a BlobStore.
func NewBlobStore(db *pgxpool.Pool) *BlobStore { return &BlobStore{db: db} }

// RegisterRoutes mounts the public blob endpoints on the given router.
func (b *BlobStore) RegisterRoutes(r gin.IRouter) {
	r.PUT("/media/blob/*key", b.put)
	r.GET("/media/blob/*key", b.get)
}

func blobKey(c *gin.Context) string {
	return strings.TrimPrefix(c.Param("key"), "/")
}

// put stores (or overwrites) the bytes for a key.
func (b *BlobStore) put(c *gin.Context) {
	key := blobKey(c)
	if key == "" {
		c.Status(http.StatusBadRequest)
		return
	}
	body := http.MaxBytesReader(c.Writer, c.Request.Body, maxBlobBytes)
	data, err := io.ReadAll(body)
	if err != nil || len(data) == 0 {
		c.Status(http.StatusBadRequest)
		return
	}
	contentType := c.GetHeader("Content-Type")
	if contentType == "" {
		contentType = "application/octet-stream"
	}
	if _, err := b.db.Exec(c.Request.Context(),
		`INSERT INTO media_blobs (key, content_type, bytes) VALUES ($1, $2, $3)
		 ON CONFLICT (key) DO UPDATE SET content_type = EXCLUDED.content_type, bytes = EXCLUDED.bytes`,
		key, contentType, data,
	); err != nil {
		c.Status(http.StatusInternalServerError)
		return
	}
	c.Status(http.StatusOK)
}

// get serves the bytes for a key.
func (b *BlobStore) get(c *gin.Context) {
	key := blobKey(c)
	var contentType string
	var data []byte
	err := b.db.QueryRow(c.Request.Context(),
		`SELECT content_type, bytes FROM media_blobs WHERE key = $1`, key,
	).Scan(&contentType, &data)
	if errors.Is(err, pgx.ErrNoRows) {
		c.Status(http.StatusNotFound)
		return
	}
	if err != nil {
		c.Status(http.StatusInternalServerError)
		return
	}
	c.Header("Cache-Control", "public, max-age=86400")
	c.Data(http.StatusOK, contentType, data)
}
