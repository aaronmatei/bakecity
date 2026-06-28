import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/primary_button.dart';
import '../application/reviews_controller.dart';
import '../domain/review.dart';

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
      messenger.showSnackBar(const SnackBar(content: Text('Thanks for your review!')));
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _stars(review.rating),
          const SizedBox(height: 12),
          if (review.comment != null && review.comment!.isNotEmpty)
            Text(review.comment!, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Text(
            'You have already reviewed this order.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _reviewForm() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Rate your order', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: _submitting ? null : () => setState(() => _rating = i),
                icon: Icon(
                  i <= _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 36,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _commentController,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'Comments (optional)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Submit review',
          icon: Icons.send_outlined,
          isLoading: _submitting,
          onPressed: _submitting ? null : _submit,
        ),
      ],
    );
  }

  Widget _stars(int rating) {
    return Row(
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(
            i <= rating ? Icons.star : Icons.star_border,
            color: Colors.amber,
            size: 28,
          ),
      ],
    );
  }
}
