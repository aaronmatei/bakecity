import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/payment_service.dart';
import '../../../widgets/primary_button.dart';
import '../application/payments_controller.dart';

/// Escrow deposit + balance payment view for an order.
class PaymentView extends ConsumerStatefulWidget {
  const PaymentView({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends ConsumerState<PaymentView> {
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(paymentsControllerProvider);
    final controller = ref.read(paymentsControllerProvider.notifier);

    ref.listen<PaymentState>(paymentsControllerProvider, (previous, next) {
      if (next.errorMessage != null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      } else if (next.result?.status == PaymentInitStatus.sent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('STK push sent. Check your phone.')),
        );
      }
    });

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'M-Pesa phone number',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Pay deposit',
            icon: Icons.lock_outline,
            isLoading: state.isProcessing,
            onPressed: () => controller.payDeposit(
              orderId: widget.orderId,
              phone: _phoneController.text.trim(),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: state.isProcessing
                ? null
                : () => controller.payBalance(
                      orderId: widget.orderId,
                      phone: _phoneController.text.trim(),
                    ),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Pay balance'),
          ),
        ],
      ),
    );
  }
}
