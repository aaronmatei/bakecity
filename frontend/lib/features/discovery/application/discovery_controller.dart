import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/constants/app_constants.dart';
import '../../../services/api_client.dart';
import '../../bakers/domain/baker_profile.dart';

/// Default map centre when the user's location is unavailable (Nairobi CBD).
const LatLng kDefaultMapCenter = LatLng(-1.2921, 36.8219);

/// Filter parameters for baker discovery / search.
class DiscoveryFilter {
  const DiscoveryFilter({
    this.query = '',
    this.radiusKm = AppConstants.defaultSearchRadiusKm,
    this.categoryId,
    this.latitude,
    this.longitude,
  });

  final String query;
  final double radiusKm;
  final String? categoryId;
  final double? latitude;
  final double? longitude;

  DiscoveryFilter copyWith({
    String? query,
    double? radiusKm,
    String? categoryId,
    double? latitude,
    double? longitude,
  }) {
    return DiscoveryFilter(
      query: query ?? this.query,
      radiusKm: radiusKm ?? this.radiusKm,
      categoryId: categoryId ?? this.categoryId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toQueryParameters() => {
        if (query.isNotEmpty) 'q': query,
        'radius_km': radiusKm,
        if (categoryId != null) 'category_id': categoryId,
        if (latitude != null) 'lat': latitude,
        if (longitude != null) 'lng': longitude,
      };
}

/// Holds the active discovery filter.
final discoveryFilterProvider =
    StateProvider<DiscoveryFilter>((ref) => const DiscoveryFilter());

/// Resolves the user's current location for distance-aware search and map
/// centring. Returns null if location services are off or permission is denied
/// (callers fall back to [kDefaultMapCenter]).
final userLocationProvider = FutureProvider<LatLng?>((ref) async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    final position = await Geolocator.getCurrentPosition();
    return LatLng(position.latitude, position.longitude);
  } catch (_) {
    return null;
  }
});

/// Searches bakers matching the active [discoveryFilterProvider].
final nearbyBakersProvider = FutureProvider<List<BakerProfile>>((ref) async {
  final filter = ref.watch(discoveryFilterProvider);
  final api = ref.watch(apiClientProvider);
  final response = await api.get<Map<String, dynamic>>(
    ApiEndpoints.searchBakers,
    queryParameters: filter.toQueryParameters(),
  );
  final items =
      (response.data?['data'] ?? response.data?['bakers'] ?? []) as List;
  return items
      .map((e) => BakerProfile.fromJson(e as Map<String, dynamic>))
      .toList();
});
