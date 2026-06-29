/// A media item attached to an order (reference photo, production photo, etc.),
/// carrying short-lived presigned URLs for display. Mirrors the backend
/// `GET /orders/:id/media` response.
class OrderMedia {
  const OrderMedia({
    required this.id,
    required this.kind,
    this.url,
    this.thumbUrl,
  });

  final String id;
  final String kind;

  /// Full-size presigned download URL (may be empty until real storage is set).
  final String? url;

  /// Thumbnail presigned URL, when a thumbnail exists.
  final String? thumbUrl;

  /// Best URL to display: prefer the thumbnail, fall back to the full image.
  String? get displayUrl {
    if (thumbUrl != null && thumbUrl!.isNotEmpty) return thumbUrl;
    if (url != null && url!.isNotEmpty) return url;
    return null;
  }

  factory OrderMedia.fromJson(Map<String, dynamic> json) {
    return OrderMedia(
      id: json['id'].toString(),
      kind: json['kind'] as String? ?? '',
      url: json['url'] as String?,
      thumbUrl: json['thumb_url'] as String?,
    );
  }
}
