import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/formatters.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../application/reviews_controller.dart';
import '../domain/review.dart';

/// Lists a baker's reviews with their aggregate rating.
class RatingsScreen extends ConsumerWidget {
  const RatingsScreen({super.key, required this.bakerId});

  final String bakerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bakerReviewsProvider(bakerId));
    return Scaffold(
      appBar: AppBar(title: const Text('Reviews')),
      body: async.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(bakerReviewsProvider(bakerId)),
        ),
        data: (data) {
          if (data.reviews.isEmpty) {
            return const EmptyState(
              icon: Icons.star_outline,
              message: 'No reviews yet.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(bakerReviewsProvider(bakerId)),
            child: ListView.separated(
              itemCount: data.reviews.length + 1,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i == 0) return _header(context, data.averageRating, data.count);
                return _reviewTile(context, data.reviews[i - 1]);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, double average, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            average.toStringAsFixed(1),
            style: theme.textTheme.displaySmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _stars(average.round()),
              const SizedBox(height: 4),
              Text('$count review${count == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewTile(BuildContext context, Review r) {
    return ListTile(
      title: _stars(r.rating),
      subtitle: Text(
        [
          if (r.comment != null && r.comment!.isNotEmpty) r.comment!,
          Formatters.relativeTime(r.createdAt),
        ].join('\n'),
      ),
      isThreeLine: r.comment != null && r.comment!.isNotEmpty,
    );
  }

  Widget _stars(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 18,
          ),
      ],
    );
  }
}
