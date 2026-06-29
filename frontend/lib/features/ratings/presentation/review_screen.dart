import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/primary_button.dart';
import '../application/reviews_controller.dart';
import '../domain/review.dart';
import 'ratings_screen.dart' show Stars;

/// Lets a customer leave (or view) a review for a completed order.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  final _commentController = TextEditingController();
  int _rating = 5;
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = Navigator.of(context);
    try {
      await ref.read(reviewsControllerProvider).submit(
            orderId: widget.orderId,
            rating: _rating,
            body: _commentController.text.trim(),
          );
      messenger.showSnackBar(
          const SnackBar(content: Text('Thanks for your review!')));
      router.pop();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final existing = ref.watch(orderReviewProvider(widget.orderId));
    return Scaffold(
      appBar: AppBar(title: const Text('Review')),
      body: existing.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => AppErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(orderReviewProvider(widget.orderId)),
        ),
        data: (review) =>
            review != null ? _existingReview(review) : _reviewForm(),
      ),
    );
  }

  Widget _existingReview(Review review) {
    final cs = context.cs;
    return ListView(
      padding: const EdgeInsets.all(Insets.screenH),
      children: [
        Container(
          padding: const EdgeInsets.all(Insets.lg),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: Radii.cardBorder,
            boxShadow: context.bake.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stars(rating: review.rating, size: 24),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: Insets.md),
                Text(review.comment!, style: context.tt.bodyLarge),
              ],
              const SizedBox(height: Insets.md),
              Text('You\'ve already reviewed this order.',
                  style: context.tt.bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _reviewForm() {
    final star = context.bake.star;
    return ListView(
      padding: const EdgeInsets.all(Insets.screenH),
      children: [
        Text('How was your order?', style: context.tt.titleLarge),
        const SizedBox(height: Insets.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: _submitting
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        setState(() => _rating = i);
                      },
                icon: Icon(
                  i <= _rating ? Icons.star_rounded : Icons.star_border_rounded,
                  color: star,
                  size: 44,
                ),
              ),
          ],
        ),
        const SizedBox(height: Insets.lg),
        TextField(
          controller: _commentController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Comments (optional)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: Insets.xl),
        PrimaryButton(
          label: 'Submit review',
          icon: Icons.send_outlined,
          isLoading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
      ],
    );
  }
}
