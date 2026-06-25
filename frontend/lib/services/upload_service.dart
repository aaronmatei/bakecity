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

/// Result of a presign request.
class PresignedUpload {
  const PresignedUpload({
    required this.uploadUrl,
    required this.publicUrl,
    this.fields = const {},
    this.method = 'PUT',
  });

  /// The URL to PUT/POST the bytes to (e.g. an S3 signed URL).
  final String uploadUrl;

  /// The URL the asset will be reachable at after upload.
  final String publicUrl;

  /// Extra form fields required for a presigned POST policy.
  final Map<String, String> fields;

  final String method;

  factory PresignedUpload.fromJson(Map<String, dynamic> json) {
    return PresignedUpload(
      uploadUrl: json['upload_url'] as String? ?? '',
      publicUrl: json['public_url'] as String? ?? '',
      method: json['method'] as String? ?? 'PUT',
      fields: (json['fields'] as Map?)?.map(
            (k, v) => MapEntry(k.toString(), v.toString()),
          ) ??
          const {},
    );
  }
}

/// Handles media selection and direct-to-storage uploads via presigned URLs.
class UploadService {
  UploadService(this._api, {ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ApiClient _api;
  final ImagePicker _picker;

  /// Opens the system picker and returns the chosen image, if any.
  Future<XFile?> pickImage({
    ImageSource source = ImageSource.gallery,
  }) {
    return _picker.pickImage(source: source, imageQuality: 85);
  }

  /// Requests a presigned upload target from the backend.
  Future<PresignedUpload> requestPresign({
    required String filename,
    required String contentType,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.mediaPresign,
      data: {
        'filename': filename,
        'content_type': contentType,
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

  /// Picks an image, requests a presign and PUTs the bytes to storage.
  ///
  /// Returns the public URL of the stored asset, or `null` if cancelled.
  Future<String?> pickAndUploadImage({
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await pickImage(source: source);
    if (file == null) return null;
    final bytes = await file.readAsBytes();
    final contentType = file.mimeType ?? 'image/jpeg';
    return uploadBytes(
      bytes: bytes,
      filename: file.name,
      contentType: contentType,
    );
  }

  /// Uploads raw bytes to storage and returns the public URL.
  Future<String> uploadBytes({
    required Uint8List bytes,
    required String filename,
    required String contentType,
  }) async {
    final presign = await requestPresign(
      filename: filename,
      contentType: contentType,
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
    return presign.publicUrl;
  }
}
