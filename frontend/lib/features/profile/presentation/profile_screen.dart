import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routes/app_routes.dart';
import '../../auth/application/auth_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        children: [
          const SizedBox(height: 16),
          Center(
            child: CircleAvatar(
              radius: 40,
              child: Text(
                (user?.displayName ?? user?.phone ?? '?')
                    .characters
                    .first
                    .toUpperCase(),
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              user?.displayName ?? 'Guest',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          if (user?.phone != null)
            Center(child: Text(user!.phone)),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            onTap: () => context.pushNamed(AppRoutes.notificationsName),
          ),
          if (user?.isBaker ?? false)
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('Baker verification'),
              subtitle: Text(
                user!.bakerVerified ? 'Verified' : 'Pending',
              ),
              onTap: () => context.pushNamed(AppRoutes.onboardingName),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Log out'),
            onTap: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
    );
  }
}
