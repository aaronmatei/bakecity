import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routes/app_routes.dart';
import '../../../widgets/dashboard_widgets.dart';
import '../../auth/application/auth_controller.dart';
import '../../bakers/domain/baker_profile.dart';
import '../../discovery/application/discovery_controller.dart';
import '../../notifications/application/notifications_controller.dart';
import '../../orders/application/orders_controller.dart';
import '../../orders/domain/order_status_ui.dart';

/// Customer landing screen with bottom navigation to the main areas.
class CustomerHomeScreen extends ConsumerStatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  ConsumerState<CustomerHomeScreen> createState() =>
      _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends ConsumerState<CustomerHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('BakeCity'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: unread > 0
                ? Badge.count(
                    count: unread,
                    child: const Icon(Icons.notifications_outlined),
                  )
                : const Icon(Icons.notifications_outlined),
            onPressed: () => context.pushNamed(AppRoutes.notificationsName),
          ),
        ],
      ),
      body: const _CustomerDashboard(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) async {
          if (i == 0) return;
          // Sections are pushed (not go) so each keeps a back button to home.
          // Highlight the tapped tab while its screen is on top, then restore
          // Home when it's popped, so the bar reflects the current section.
          setState(() => _index = i);
          switch (i) {
            case 1:
              await context.pushNamed(AppRoutes.discoveryName);
            case 2:
              await context.pushNamed(AppRoutes.ordersName);
            case 3:
              await context.pushNamed(AppRoutes.profileName);
          }
          if (mounted) setState(() => _index = 0);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _CustomerDashboard extends ConsumerWidget {
  const _CustomerDashboard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final ordersAsync = ref.watch(ordersControllerProvider);
    final bakersAsync = ref.watch(nearbyBakersProvider);
    final firstName = (user?.displayName ?? '').split(' ').first;

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(ordersControllerProvider.notifier).refresh();
        ref.invalidate(nearbyBakersProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _Greeting(
            name: firstName.isEmpty ? 'there' : firstName,
            subtitle: 'What shall we bake today?',
          ),
          const SizedBox(height: 20),
          _DiscoverCard(
            onTap: () => context.pushNamed(AppRoutes.discoveryName),
          ),
          const SizedBox(height: 24),
          DashSectionHeader(
            title: 'Your orders',
            actionLabel: 'View all',
            onAction: () => context.pushNamed(AppRoutes.ordersName),
          ),
          const SizedBox(height: 8),
          ordersAsync.when(
            loading: () => const DashLoading(),
            error: (e, _) => DashError(
              onRetry: () =>
                  ref.read(ordersControllerProvider.notifier).refresh(),
            ),
            data: (list) {
              if (list.isEmpty) {
                return const DashHint(
                  icon: Icons.receipt_long_outlined,
                  text: 'No orders yet. Discover a baker to place your first '
                      'custom order.',
                );
              }
              final active =
                  list.where((o) => o.status.isActive).take(3).toList();
              if (active.isEmpty) {
                return const DashHint(
                  icon: Icons.check_circle_outline,
                  text: 'No active orders right now. Browse bakers to start a '
                      'new one.',
                );
              }
              return Column(
                children: [
                  for (final o in active)
                    OrderSummaryTile(
                      order: o,
                      onTap: () => context.pushNamed(
                        AppRoutes.orderDetailName,
                        pathParameters: {'orderId': o.id},
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          DashSectionHeader(
            title: 'Bakers near you',
            actionLabel: 'See all',
            onAction: () => context.pushNamed(AppRoutes.discoveryName),
          ),
          const SizedBox(height: 8),
          bakersAsync.when(
            loading: () => const DashLoading(),
            error: (e, _) => DashError(
              onRetry: () => ref.invalidate(nearbyBakersProvider),
            ),
            data: (bakers) {
              if (bakers.isEmpty) {
                return const DashHint(
                  icon: Icons.storefront_outlined,
                  text: 'No bakers nearby yet. Try widening your search.',
                );
              }
              final shown = bakers.take(8).toList();
              return SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: shown.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final b = shown[i];
                    return _BakerCard(
                      baker: b,
                      onTap: () => context.pushNamed(
                        AppRoutes.bakerStorefrontName,
                        pathParameters: {'bakerId': b.id},
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.subtitle});

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Text(
            name.characters.first.toUpperCase(),
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hello, $name 👋',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(subtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DiscoverCard extends StatelessWidget {
  const _DiscoverCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.primary.withValues(alpha: 0.75),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Find your baker',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                      )),
                  const SizedBox(height: 4),
                  Text(
                    'Browse nearby bakeries and order a custom cake.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            CircleAvatar(
              backgroundColor:
                  theme.colorScheme.onPrimary.withValues(alpha: 0.2),
              child: Icon(Icons.search, color: theme.colorScheme.onPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _BakerCard extends StatelessWidget {
  const _BakerCard({required this.baker, required this.onTap});

  final BakerProfile baker;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 168,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: theme.colorScheme.secondaryContainer,
                      child: Icon(Icons.storefront_outlined,
                          color: theme.colorScheme.onSecondaryContainer),
                    ),
                    if (baker.isVerified) ...[
                      const Spacer(),
                      Icon(Icons.verified,
                          size: 18, color: theme.colorScheme.primary),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  baker.businessName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 14, color: Colors.amber),
                    const SizedBox(width: 2),
                    Text(
                      baker.rating > 0 ? baker.rating.toStringAsFixed(1) : 'New',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (baker.distanceKm != null) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.place_outlined,
                          size: 13, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text('${baker.distanceKm!.toStringAsFixed(1)} km',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
