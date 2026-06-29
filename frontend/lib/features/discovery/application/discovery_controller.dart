import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../services/api_client.dart';
import '../../bakers/domain/baker_profile.dart';

/// Default map centre when the user's location is unavailable (Nairobi CBD).
const LatLng kDefaultMapCenter = LatLng(-1.2921, 36.8219);

/// Filter parameters for baker discovery / search. Mirrors the backend's
/// GET /search/bakers contract: `category` is a slug, and `radius_km` only
/// applies when a location is set (null = no distance limit).
class DiscoveryFilter {
  const DiscoveryFilter({
    this.query = '',
    this.radiusKm,
    this.categorySlug,
    this.minRating,
    this.minPrice,
    this.maxPrice,
    this.latitude,
    this.longitude,
  });

  final String query;
  final double? radiusKm;
  final String? categorySlug;
  final double? minRating;
  final double? minPrice;
  final double? maxPrice;
  final double? latitude;
  final double? longitude;

  DiscoveryFilter copyWith({
    String? query,
    double? radiusKm,
    String? categorySlug,
    double? minRating,
    double? minPrice,
    double? maxPrice,
    double? latitude,
    double? longitude,
    bool clearRadius = false,
    bool clearCategory = false,
    bool clearRating = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return DiscoveryFilter(
      query: query ?? this.query,
      radiusKm: clearRadius ? null : (radiusKm ?? this.radiusKm),
      categorySlug: clearCategory ? null : (categorySlug ?? this.categorySlug),
      minRating: clearRating ? null : (minRating ?? this.minRating),
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  Map<String, dynamic> toQueryParameters() => {
        if (query.isNotEmpty) 'q': query,
        if (radiusKm != null) 'radius_km': radiusKm,
        if (categorySlug != null) 'category': categorySlug,
        if (minRating != null) 'min_rating': minRating,
        if (minPrice != null) 'min_price': minPrice,
        if (maxPrice != null) 'max_price': maxPrice,
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
