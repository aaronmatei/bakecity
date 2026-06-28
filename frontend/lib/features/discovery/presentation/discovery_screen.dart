import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../application/discovery_controller.dart';

/// Search + map of nearby bakers.
class DiscoveryScreen extends ConsumerWidget {
  const DiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bakers = ref.watch(nearbyBakersProvider);
    final filter = ref.watch(discoveryFilterProvider);

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
          // Map placeholder. TODO: integrate google_maps_flutter with markers
          // for nearby bakers plus geolocator for the user's position.
          Container(
            height: 160,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.map_outlined, size: 36),
                SizedBox(height: 8),
                Text('Map of nearby bakers'),
              ],
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
                        onTap: () {
                          // TODO: Navigate to baker storefront.
                        },
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
