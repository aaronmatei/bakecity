import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../widgets/empty_state.dart';

/// Lists reviews for a baker, or lets a customer leave a review.
class RatingsScreen extends ConsumerWidget {
  const RatingsScreen({super.key, this.bakerId});

  final String? bakerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      // TODO: Load reviews via ApiEndpoints.bakerReviews(bakerId) / reviews.
      body: const EmptyState(
        icon: Icons.star_outline,
        message: 'No reviews yet.',
      ),
    );
  }
}
