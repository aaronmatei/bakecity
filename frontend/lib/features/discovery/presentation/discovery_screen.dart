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
import '../../products/application/products_controller.dart';
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
          const _DiscoveryFilterBar(),
          const SizedBox(height: 8),
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

/// Horizontal filter row: distance, rating, price popups + category chips, all
/// wired to the active [discoveryFilterProvider].
class _DiscoveryFilterBar extends ConsumerWidget {
  const _DiscoveryFilterBar();

  static const List<double?> _radii = [null, 2, 5, 10, 20, 50];
  static const List<double?> _ratings = [null, 3, 4, 4.5];

  // (label, minPrice, maxPrice) brackets in KES.
  static const List<(String, double?, double?)> _priceBrackets = [
    ('Any price', null, null),
    ('Under 2k', null, 2000.0),
    ('2k–5k', 2000.0, 5000.0),
    ('5k–10k', 5000.0, 10000.0),
    ('Over 10k', 10000.0, null),
  ];

  static String _radiusLabel(double? km) =>
      km == null ? 'Any distance' : 'Within ${km.toInt()} km';

  static String _ratingLabel(double? r) {
    if (r == null) return 'Any rating';
    final s = r % 1 == 0 ? r.toInt().toString() : r.toString();
    return '$s★+';
  }

  static String _priceLabel(double? min, double? max) {
    for (final (label, lo, hi) in _priceBrackets) {
      if (lo == min && hi == max) return label;
    }
    return 'Price';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(discoveryFilterProvider);
    final categories = ref.watch(categoriesProvider);
    final notifier = ref.read(discoveryFilterProvider.notifier);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          PopupMenuButton<double?>(
            initialValue: filter.radiusKm,
            onSelected: (value) => notifier.state =
                filter.copyWith(radiusKm: value, clearRadius: value == null),
            itemBuilder: (_) => [
              for (final r in _radii)
                PopupMenuItem(value: r, child: Text(_radiusLabel(r))),
            ],
            child: _FilterChipButton(
              icon: Icons.place_outlined,
              label: _radiusLabel(filter.radiusKm),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<double?>(
            initialValue: filter.minRating,
            onSelected: (value) => notifier.state =
                filter.copyWith(minRating: value, clearRating: value == null),
            itemBuilder: (_) => [
              for (final r in _ratings)
                PopupMenuItem(value: r, child: Text(_ratingLabel(r))),
            ],
            child: _FilterChipButton(
              icon: Icons.star_outline,
              label: _ratingLabel(filter.minRating),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<(String, double?, double?)>(
            onSelected: (bracket) {
              final (_, lo, hi) = bracket;
              notifier.state = filter.copyWith(
                minPrice: lo,
                maxPrice: hi,
                clearMinPrice: lo == null,
                clearMaxPrice: hi == null,
              );
            },
            itemBuilder: (_) => [
              for (final bracket in _priceBrackets)
                PopupMenuItem(value: bracket, child: Text(bracket.$1)),
            ],
            child: _FilterChipButton(
              icon: Icons.sell_outlined,
              label: _priceLabel(filter.minPrice, filter.maxPrice),
            ),
          ),
          const SizedBox(width: 8),
          _CategoryChip(
            label: 'All',
            selected: filter.categorySlug == null,
            onSelected: () => notifier.state = filter.copyWith(clearCategory: true),
          ),
          ...categories.maybeWhen(
            data: (cats) => [
              for (final cat in cats)
                if (cat.slug != null)
                  _CategoryChip(
                    label: cat.name,
                    selected: filter.categorySlug == cat.slug,
                    onSelected: () => notifier.state =
                        filter.copyWith(categorySlug: cat.slug),
                  ),
            ],
            orElse: () => const [],
          ),
        ],
      ),
    );
  }
}

/// A chip styled as a dropdown trigger (icon + label + caret).
class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onSelected(),
      ),
    );
  }
}
