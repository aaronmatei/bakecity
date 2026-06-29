import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/network_photo.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/rating_pill.dart';
import '../../bakers/domain/baker_profile.dart';
import '../../products/application/products_controller.dart';
import '../application/discovery_controller.dart';

/// Discover nearby bakers: search, filters, a map and a results list.
class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen> {
  final Completer<GoogleMapController> _mapController = Completer();
  final _searchController = TextEditingController();
  bool _hasLocation = false;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
    final cs = context.cs;
    final bakers = ref.watch(nearbyBakersProvider);
    final filter = ref.watch(discoveryFilterProvider);
    final markers = bakers.maybeWhen(
      data: _markersFor,
      orElse: () => <Marker>{},
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Discover')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.screenH, Insets.sm, Insets.screenH, Insets.md),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      color: cs.onSurfaceVariant, size: 22),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Search bakers or bakes',
                      ),
                      onSubmitted: (value) =>
                          ref.read(discoveryFilterProvider.notifier).state =
                              filter.copyWith(query: value),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const _DiscoveryFilterBar(),
          const SizedBox(height: Insets.md),
          Container(
            height: 180,
            margin: const EdgeInsets.symmetric(horizontal: Insets.screenH),
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(borderRadius: Radii.cardBorder),
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
          const SizedBox(height: Insets.md),
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
                    title: 'No bakers nearby',
                    message: 'Try widening your distance or clearing filters.',
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(Insets.screenH),
                  itemCount: list.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: Insets.md),
                  itemBuilder: (context, i) => _BakerListCard(
                    baker: list[i],
                    onTap: () => _openStorefront(list[i].id),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A full-width baker row card for the results list.
class _BakerListCard extends StatelessWidget {
  const _BakerListCard({required this.baker, required this.onTap});
  final BakerProfile baker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(Insets.sm),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: Radii.cardBorder,
          boxShadow: context.bake.cardShadow,
        ),
        child: Row(
          children: [
            NetworkPhoto(
              url: baker.coverImageUrl,
              width: 76,
              height: 76,
              radius: Radii.chip,
              fallbackIcon: Icons.storefront_outlined,
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          baker.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (baker.isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified, size: 16, color: cs.primary),
                      ],
                    ],
                  ),
                  const SizedBox(height: Insets.sm),
                  Row(
                    children: [
                      RatingPill(
                          rating: baker.rating,
                          reviewCount: baker.reviewCount),
                      if (baker.distanceKm != null) ...[
                        const SizedBox(width: Insets.sm),
                        Icon(Icons.place_outlined,
                            size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text('${baker.distanceKm!.toStringAsFixed(1)} km',
                            style: context.tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Horizontal filter row: distance, rating, price popups + category chips.
class _DiscoveryFilterBar extends ConsumerWidget {
  const _DiscoveryFilterBar();

  static const List<double?> _radii = [null, 2, 5, 10, 20, 50];
  static const List<double?> _ratings = [null, 3, 4, 4.5];

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
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Insets.screenH),
        children: [
          PopupMenuButton<double?>(
            initialValue: filter.radiusKm,
            onSelected: (value) => notifier.state =
                filter.copyWith(radiusKm: value, clearRadius: value == null),
            itemBuilder: (_) => [
              for (final r in _radii)
                PopupMenuItem(value: r, child: Text(_radiusLabel(r))),
            ],
            child: _FilterPill(
              icon: Icons.place_outlined,
              label: _radiusLabel(filter.radiusKm),
              active: filter.radiusKm != null,
              caret: true,
            ),
          ),
          const SizedBox(width: Insets.sm),
          PopupMenuButton<double?>(
            initialValue: filter.minRating,
            onSelected: (value) => notifier.state =
                filter.copyWith(minRating: value, clearRating: value == null),
            itemBuilder: (_) => [
              for (final r in _ratings)
                PopupMenuItem(value: r, child: Text(_ratingLabel(r))),
            ],
            child: _FilterPill(
              icon: Icons.star_outline,
              label: _ratingLabel(filter.minRating),
              active: filter.minRating != null,
              caret: true,
            ),
          ),
          const SizedBox(width: Insets.sm),
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
            child: _FilterPill(
              icon: Icons.sell_outlined,
              label: _priceLabel(filter.minPrice, filter.maxPrice),
              active: filter.minPrice != null || filter.maxPrice != null,
              caret: true,
            ),
          ),
          const SizedBox(width: Insets.sm),
          _FilterPill(
            label: 'All',
            active: filter.categorySlug == null,
            onTap: () => notifier.state = filter.copyWith(clearCategory: true),
          ),
          ...categories.maybeWhen(
            data: (cats) => [
              for (final cat in cats)
                if (cat.slug != null) ...[
                  const SizedBox(width: Insets.sm),
                  _FilterPill(
                    label: cat.name,
                    active: filter.categorySlug == cat.slug,
                    onTap: () => notifier.state =
                        filter.copyWith(categorySlug: cat.slug),
                  ),
                ],
            ],
            orElse: () => const [],
          ),
        ],
      ),
    );
  }
}

/// A token-styled filter pill: dropdown trigger or toggle.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    this.icon,
    this.active = false,
    this.caret = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final bool active;
  final bool caret;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final fg = active ? cs.onPrimary : cs.onSurface;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 8),
      decoration: BoxDecoration(
        color: active ? cs.primary : cs.surface,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: active ? cs.primary : cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: context.tt.labelLarge
                  ?.copyWith(color: fg, fontWeight: FontWeight.w600)),
          if (caret) Icon(Icons.arrow_drop_down, size: 18, color: fg),
        ],
      ),
    );
    return onTap != null ? PressScale(onTap: onTap, child: pill) : pill;
  }
}
