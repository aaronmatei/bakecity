import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/helpers/formatters.dart';
import '../../../core/theme/app_tokens.dart';
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
              title: 'No reviews yet',
              message: 'Be the first to review this bakery.',
            );
          }
          return RefreshIndicator(
            color: context.cs.primary,
            onRefresh: () async => ref.invalidate(bakerReviewsProvider(bakerId)),
            child: ListView.separated(
              padding: const EdgeInsets.all(Insets.screenH),
              itemCount: data.reviews.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: Insets.md),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _SummaryCard(
                      average: data.averageRating, count: data.count);
                }
                return _ReviewCard(review: data.reviews[i - 1]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.average, required this.count});
  final double average;
  final int count;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Container(
      padding: const EdgeInsets.all(Insets.xl),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: Radii.cardBorder,
        boxShadow: context.bake.cardShadow,
      ),
      child: Row(
        children: [
          Text(average.toStringAsFixed(1),
              style: context.tt.displaySmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: Insets.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stars(rating: average.round(), size: 20),
              const SizedBox(height: Insets.xs),
              Text('$count review${count == 1 ? '' : 's'}',
                  style: context.tt.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});
  final Review review;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final hasComment = review.comment != null && review.comment!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(Insets.lg),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: Radii.cardBorder,
        boxShadow: context.bake.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Stars(rating: review.rating, size: 16),
              Text(Formatters.relativeTime(review.createdAt),
                  style: context.tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          if (hasComment) ...[
            const SizedBox(height: Insets.sm),
            Text(review.comment!, style: context.tt.bodyMedium),
          ],
        ],
      ),
    );
  }
}

/// A row of filled/empty stars in the brand star colour.
class Stars extends StatelessWidget {
  const Stars({super.key, required this.rating, this.size = 18});
  final int rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    final star = context.bake.star;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star_rounded : Icons.star_border_rounded,
            color: star,
            size: size,
          ),
      ],
    );
  }
}
