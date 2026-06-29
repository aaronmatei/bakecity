package storage

import (
	"context"
	"time"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/credentials"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// S3Presigner is a production Presigner backed by any S3-compatible object
// store: AWS S3, Cloudflare R2, MinIO, etc. It issues real SigV4 presigned
// URLs, so PUTs actually store bytes and GETs actually serve them.
//
// For Cloudflare R2: endpoint is https://<ACCOUNT_ID>.r2.cloudflarestorage.com,
// region is "auto", and credentials are an R2 API token's access key/secret.
type S3Presigner struct {
	client *s3.PresignClient
	bucket string
}

var _ Presigner = (*S3Presigner)(nil)

// NewS3Presigner constructs an S3Presigner. A non-empty endpoint overrides the
// default AWS endpoint (set it for R2/MinIO; leave empty for real AWS S3).
// Path-style addressing is used so a custom endpoint doesn't require per-bucket
// DNS — which R2 and MinIO both prefer.
func NewS3Presigner(endpoint, region, bucket, accessKey, secretKey string) *S3Presigner {
	opts := s3.Options{
		Region: region,
		Credentials: credentials.NewStaticCredentialsProvider(
			accessKey, secretKey, "",
		),
		UsePathStyle: true,
	}
	if endpoint != "" {
		opts.BaseEndpoint = aws.String(endpoint)
	}
	client := s3.New(opts)
	return &S3Presigner{client: s3.NewPresignClient(client), bucket: bucket}
}

// PresignUpload returns a presigned PUT URL the client uploads bytes to. The
// signed ContentType must match the Content-Type the client sends on the PUT.
func (p *S3Presigner) PresignUpload(ctx context.Context, key, contentType string, expiry time.Duration) (string, error) {
	req, err := p.client.PresignPutObject(ctx, &s3.PutObjectInput{
		Bucket:      aws.String(p.bucket),
		Key:         aws.String(key),
		ContentType: aws.String(contentType),
	}, s3.WithPresignExpires(expiry))
	if err != nil {
		return "", err
	}
	return req.URL, nil
}

// PresignDownload returns a presigned GET URL for displaying the object. An
// empty key yields an empty URL (nothing to serve).
func (p *S3Presigner) PresignDownload(ctx context.Context, key string, expiry time.Duration) (string, error) {
	if key == "" {
		return "", nil
	}
	req, err := p.client.PresignGetObject(ctx, &s3.GetObjectInput{
		Bucket: aws.String(p.bucket),
		Key:    aws.String(key),
	}, s3.WithPresignExpires(expiry))
	if err != nil {
		return "", err
	}
	return req.URL, nil
}
