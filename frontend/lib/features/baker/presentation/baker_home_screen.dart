import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routes/app_routes.dart';

/// Baker dashboard landing screen.
class BakerHomeScreen extends ConsumerStatefulWidget {
  const BakerHomeScreen({super.key});

  @override
  ConsumerState<BakerHomeScreen> createState() => _BakerHomeScreenState();
}

class _BakerHomeScreenState extends ConsumerState<BakerHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Baker Dashboard')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Manage incoming orders, quotes and production here.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          setState(() => _index = i);
          switch (i) {
            case 1:
              context.goNamed(AppRoutes.ordersName);
            case 2:
              context.goNamed(AppRoutes.profileName);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
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
