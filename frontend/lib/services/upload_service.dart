import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/constants/api_endpoints.dart';
import '../core/errors/app_exception.dart';
import 'api_client.dart';

/// Provides the [UploadService].
final uploadServiceProvider = Provider<UploadService>((ref) {
  return UploadService(ref.watch(apiClientProvider));
});

/// Media kinds accepted by the backend (the upload's purpose).
class MediaKind {
  const MediaKind._();
  static const String reference = 'reference';
  static const String production = 'production';
  static const String deliveryProof = 'delivery_proof';
  static const String product = 'product';
  static const String bakerCover = 'baker_cover'; // storefront cover (owner-scoped)
  static const String bakerAvatar = 'baker_avatar'; // storefront logo (owner-scoped)
  static const String kyc = 'kyc'; // baker identity document (owner-scoped)
}

/// Presigned upload target returned by POST /media/presign.
class PresignedUpload {
  const PresignedUpload({
    required this.uploadUrl,
    required this.s3Key,
    required this.mediaId,
  });

  /// The URL to PUT the bytes to (S3 signed URL).
  final String uploadUrl;
  final String s3Key;

  /// The media record id, referenced by orders/production/delivery once ready.
  final String mediaId;

  factory PresignedUpload.fromJson(Map<String, dynamic> json) {
    return PresignedUpload(
      uploadUrl: json['upload_url'] as String? ?? '',
      s3Key: json['s3_key'] as String? ?? '',
      mediaId: json['media_id'].toString(),
    );
  }
}

/// Handles media selection and the direct-to-storage upload flow:
/// presign -> PUT bytes to storage -> mark complete. Returns the media id.
class UploadService {
  UploadService(this._api, {ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ApiClient _api;
  final ImagePicker _picker;

  /// Opens the system picker and returns the chosen image, if any.
  Future<XFile?> pickImage({ImageSource source = ImageSource.gallery}) {
    return _picker.pickImage(source: source, imageQuality: 85);
  }

  /// Requests a presigned upload target for [kind] (optionally tied to an order).
  Future<PresignedUpload> requestPresign({
    required String kind,
    required String contentType,
    String? orderId,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.mediaPresign,
      data: {
        'kind': kind,
        'content_type': contentType,
        if (orderId != null) 'order_id': orderId,
      },
    );
    final data = response.data;
    if (data == null) {
      throw const ApiException(
        statusCode: 500,
        message: 'Empty presign response.',
      );
    }
    return PresignedUpload.fromJson(data);
  }

  /// Marks a media record uploaded once the bytes are stored.
  Future<void> complete(String mediaId) =>
      _api.post<void>(ApiEndpoints.mediaComplete(mediaId));

  /// Picks an image and runs the full upload flow. Returns the media id, or
  /// null if the user cancelled.
  Future<String?> pickAndUpload({
    required String kind,
    String? orderId,
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await pickImage(source: source);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    return uploadBytes(
      bytes: bytes,
      contentType: file.mimeType ?? 'image/jpeg',
      kind: kind,
      orderId: orderId,
    );
  }

  /// Uploads raw bytes via the presign flow and returns the media id.
  Future<String> uploadBytes({
    required Uint8List bytes,
    required String contentType,
    required String kind,
    String? orderId,
  }) async {
    final presign = await requestPresign(
      kind: kind,
      contentType: contentType,
      orderId: orderId,
    );

    // Upload straight to the storage provider (bypasses our API auth headers).
    final storageDio = Dio();
    try {
      await storageDio.put<void>(
        presign.uploadUrl,
        data: Stream.fromIterable([bytes]),
        options: Options(
          headers: {
            'Content-Type': contentType,
            Headers.contentLengthHeader: bytes.length,
          },
        ),
      );
    } catch (error) {
      throw mapDioError(error);
    } finally {
      storageDio.close();
    }

    await complete(presign.mediaId);
    return presign.mediaId;
  }
}
