import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routes/app_routes.dart';
import '../../home/presentation/home_feed.dart';

/// Customer landing screen: the image-forward home feed with bottom navigation
/// to the main areas. Sections are pushed (not switched) so each keeps a back
/// button; the bar highlights the tapped tab while its screen is on top.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: const HomeFeed(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) async {
          if (i == 0) return;
          setState(() => _index = i);
          switch (i) {
            case 1:
              await context.pushNamed(AppRoutes.discoveryName);
            case 2:
              await context.pushNamed(AppRoutes.favoritesName);
            case 3:
              await context.pushNamed(AppRoutes.ordersName);
            case 4:
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
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: 'Favorites',
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
