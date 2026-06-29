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
                    average: data.averageRating,
                    count: data.count,
                    distribution: data.distribution,
                  );
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
  const _SummaryCard({
    required this.average,
    required this.count,
    required this.distribution,
  });
  final double average;
  final int count;
  final List<int> distribution;

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            children: [
              Text(average.toStringAsFixed(1),
                  style: context.tt.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Stars(rating: average.round(), size: 18),
              const SizedBox(height: Insets.xs),
              Text('$count review${count == 1 ? '' : 's'}',
                  style: context.tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(width: Insets.xl),
          // Per-star distribution bars (5★ at top).
          Expanded(
            child: Column(
              children: [
                for (var star = 5; star >= 1; star--)
                  _DistRow(
                    star: star,
                    n: distribution[star - 1],
                    total: count,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One row of the rating histogram: "5 ★ ▓▓▓░░ 12".
class _DistRow extends StatelessWidget {
  const _DistRow({required this.star, required this.n, required this.total});
  final int star;
  final int n;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final fraction = total == 0 ? 0.0 : n / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 10,
            child: Text('$star',
                textAlign: TextAlign.end, style: context.tt.bodySmall),
          ),
          const SizedBox(width: 2),
          Icon(Icons.star_rounded, size: 12, color: context.bake.star),
          const SizedBox(width: Insets.sm),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(context.bake.star),
              ),
            ),
          ),
          const SizedBox(width: Insets.sm),
          SizedBox(
            width: 22,
            child: Text('$n',
                textAlign: TextAlign.end,
                style: context.tt.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant)),
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
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: cs.primary.withValues(alpha: 0.12),
                child: Icon(Icons.person_outline, size: 18, color: cs.primary),
              ),
              const SizedBox(width: Insets.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Verified customer',
                            style: context.tt.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        Icon(Icons.verified,
                            size: 14, color: context.bake.success),
                      ],
                    ),
                    Text(Formatters.relativeTime(review.createdAt),
                        style: context.tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              Stars(rating: review.rating, size: 16),
            ],
          ),
          if (hasComment) ...[
            const SizedBox(height: Insets.md),
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
