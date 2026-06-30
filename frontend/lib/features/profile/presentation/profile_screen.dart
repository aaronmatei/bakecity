import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/press_scale.dart';
import '../../auth/application/auth_controller.dart';
import '../../onboarding/application/onboarding_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final cs = context.cs;
    final isBaker = user?.isBaker ?? false;
    final myBakerId =
        isBaker ? ref.watch(onboardingControllerProvider).valueOrNull?.id : null;
    final name = user?.displayName ?? 'Guest';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(Insets.screenH),
        children: [
          // Header banner.
          Container(
            padding: const EdgeInsets.all(Insets.xl),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.cardLg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [cs.primary, cs.secondary],
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: Colors.white.withValues(alpha: 0.25),
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: Insets.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.tt.titleLarge
                              ?.copyWith(color: Colors.white)),
                      if (user?.phone != null)
                        Text(user!.phone,
                            style: context.tt.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9))),
                      const SizedBox(height: Insets.sm),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Insets.md, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: Radii.chipBorder,
                        ),
                        child: Text(isBaker ? 'Baker' : 'Customer',
                            style: context.tt.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Insets.xl),
          _Group(children: [
            _SettingsTile(
              icon: Icons.notifications_outlined,
              label: 'Notifications',
              onTap: () => context.pushNamed(AppRoutes.notificationsName),
            ),
            if (!isBaker)
              _SettingsTile(
                icon: Icons.favorite_border,
                label: 'Favorites',
                onTap: () => context.pushNamed(AppRoutes.favoritesName),
              ),
            _SettingsTile(
              icon: Icons.receipt_long_outlined,
              label: 'Orders',
              onTap: () => context.pushNamed(AppRoutes.ordersName),
            ),
          ]),
          if (isBaker) ...[
            const SizedBox(height: Insets.lg),
            _Group(children: [
              _SettingsTile(
                icon: Icons.storefront_outlined,
                label: 'Manage my menu',
                onTap: () => context.pushNamed(AppRoutes.manageProductsName),
              ),
              if (myBakerId != null)
                _SettingsTile(
                  icon: Icons.visibility_outlined,
                  label: 'View my storefront',
                  onTap: () => context.pushNamed(
                    AppRoutes.bakerStorefrontName,
                    pathParameters: {'bakerId': myBakerId},
                  ),
                ),
              _SettingsTile(
                icon: Icons.insights_outlined,
                label: 'Insights',
                onTap: () => context.pushNamed(AppRoutes.insightsName),
              ),
              _SettingsTile(
                icon: Icons.account_balance_wallet_outlined,
                label: 'Earnings & payouts',
                onTap: () => context.pushNamed(AppRoutes.payoutsName),
              ),
              _SettingsTile(
                icon: Icons.verified_outlined,
                label: 'Baker verification',
                subtitle: user!.bakerVerified ? 'Verified' : 'Pending',
                onTap: () => context.pushNamed(AppRoutes.onboardingName),
              ),
            ]),
          ],
          const SizedBox(height: Insets.lg),
          _Group(children: [
            _SettingsTile(
              icon: Icons.logout,
              label: 'Log out',
              tone: context.bake.berry,
              onTap: () => ref.read(authControllerProvider.notifier).logout(),
            ),
          ]),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cs.surface,
        borderRadius: Radii.cardBorder,
        boxShadow: context.bake.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: context.cs.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.tone,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final color = tone ?? cs.onSurface;
    return PressScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Insets.lg, vertical: Insets.lg),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (tone ?? cs.primary).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: tone ?? cs.primary),
            ),
            const SizedBox(width: Insets.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: context.tt.titleSmall?.copyWith(
                          color: color, fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: context.tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
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
