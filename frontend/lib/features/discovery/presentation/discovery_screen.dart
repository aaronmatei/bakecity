import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../routes/app_routes.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../bakers/domain/baker_profile.dart';
import '../application/discovery_controller.dart';

/// Search + map of nearby bakers.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  /// Resolves the user's location, makes the search distance-aware, and recentres
  /// the map. Silently no-ops when location is unavailable (map stays on the
  /// default centre).
  Future<void> _initLocation() async {
    final location = await ref.read(userLocationProvider.future);
    if (location == null || !mounted) return;

    final filter = ref.read(discoveryFilterProvider);
    ref.read(discoveryFilterProvider.notifier).state = filter.copyWith(
      latitude: location.latitude,
      longitude: location.longitude,
    );
    setState(() => _hasLocation = true);

    if (_mapController.isCompleted) {
      final controller = await _mapController.future;
      await controller.animateCamera(CameraUpdate.newLatLng(location));
    }
  }

  void _openStorefront(String bakerId) {
    context.pushNamed(
      AppRoutes.bakerStorefrontName,
      pathParameters: {'bakerId': bakerId},
    );
  }

  Set<Marker> _markersFor(List<BakerProfile> bakers) {
    return {
      for (final baker in bakers)
        if (baker.latitude != null && baker.longitude != null)
          Marker(
            markerId: MarkerId(baker.id),
            position: LatLng(baker.latitude!, baker.longitude!),
            infoWindow: InfoWindow(
              title: baker.businessName,
              snippet: '${baker.rating.toStringAsFixed(1)} ★ — tap to view',
              onTap: () => _openStorefront(baker.id),
            ),
          ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final bakers = ref.watch(nearbyBakersProvider);
    final filter = ref.watch(discoveryFilterProvider);
    final markers = bakers.maybeWhen(
      data: _markersFor,
      orElse: () => <Marker>{},
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Discover bakers')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SearchBar(
              hintText: 'Search bakers or bakes',
              leading: const Icon(Icons.search),
              onSubmitted: (value) {
                ref.read(discoveryFilterProvider.notifier).state =
                    filter.copyWith(query: value);
              },
            ),
          ),
          Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: kDefaultMapCenter,
                zoom: 12,
              ),
              markers: markers,
              myLocationEnabled: _hasLocation,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              onMapCreated: (controller) {
                if (!_mapController.isCompleted) {
                  _mapController.complete(controller);
                }
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: bakers.when(
              loading: () => const LoadingIndicator(label: 'Finding bakers…'),
              error: (e, _) => AppErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(nearbyBakersProvider),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.storefront_outlined,
                    message: 'No bakers found nearby. Try widening your search.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final baker = list[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.cake_outlined),
                        ),
                        title: Text(baker.businessName),
                        subtitle: Text(
                          '${baker.rating.toStringAsFixed(1)} ★ '
                          '(${baker.reviewCount})'
                          '${baker.distanceKm != null ? ' • ${baker.distanceKm!.toStringAsFixed(1)} km' : ''}',
                        ),
                        trailing: baker.isVerified
                            ? const Icon(Icons.verified, size: 18)
                            : null,
                        onTap: () => _openStorefront(baker.id),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
