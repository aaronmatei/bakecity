import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/helpers/validators.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/primary_button.dart';
import '../../products/application/products_controller.dart';
import '../../products/domain/product.dart';
import '../application/orders_controller.dart';

/// Collects the details for a custom-order request against a product and sends
/// it to the baker as a quote request (the first step of the escrow lifecycle).
class OrderRequestScreen extends ConsumerWidget {
  const OrderRequestScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(productDetailProvider(productId));

    return Scaffold(
      appBar: AppBar(title: const Text('Request a custom order')),
      body: SafeArea(
        child: product.when(
          loading: () => const LoadingIndicator(),
          error: (e, _) => AppErrorView(
            message: e is AppException ? e.message : e.toString(),
            onRetry: () => ref.invalidate(productDetailProvider(productId)),
          ),
          data: (p) => _OrderRequestForm(product: p),
        ),
      ),
    );
  }
}

class _OrderRequestForm extends ConsumerStatefulWidget {
  const _OrderRequestForm({required this.product});

  final Product product;

  @override
  ConsumerState<_OrderRequestForm> createState() => _OrderRequestFormState();
}

class _OrderRequestFormState extends ConsumerState<_OrderRequestForm> {
  final _formKey = GlobalKey<FormState>();
  final _servings = TextEditingController();
  final _flavor = TextEditingController();
  final _message = TextEditingController();
  final _notes = TextEditingController();
  final _address = TextEditingController();

  DateTime? _eventDate;
  bool _submitting = false;

  /// The earliest date the baker could fulfil, given the product's lead time.
  DateTime get _earliestDate =>
      DateTime.now().add(Duration(days: widget.product.leadTimeDays));

  @override
  void dispose() {
    _servings.dispose();
    _flavor.dispose();
    _message.dispose();
    _notes.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final earliest = _earliestDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? earliest,
      firstDate: earliest,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select your event date',
    );
    if (picked != null) setState(() => _eventDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose an event date.')),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      final order = await ref.read(ordersControllerProvider.notifier).createOrder(
            bakerId: widget.product.bakerId,
            productId: widget.product.id,
            eventDate: _eventDate!,
            deliveryAddress: _address.text.trim(),
            specs: _buildSpecs(),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent — the baker will quote you.')),
      );
      // Replace so the back button returns to the product, not this form.
      context.pushReplacementNamed(
        AppRoutes.orderDetailName,
        pathParameters: {'orderId': order.id},
      );
    } on AppException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Collects the non-empty custom fields into the backend's key/value specs.
  Map<String, String> _buildSpecs() {
    final specs = <String, String>{};
    void add(String key, TextEditingController c) {
      final v = c.text.trim();
      if (v.isNotEmpty) specs[key] = v;
    }

    add('servings', _servings);
    add('flavor', _flavor);
    add('message', _message);
    add('notes', _notes);
    return specs;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = widget.product;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.cake_outlined),
                  title: Text(p.name),
                  subtitle: Text(
                    'From ${Formatters.currencyFromCents(p.basePriceCents)} • '
                    'lead time ${p.leadTimeDays} day(s)',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tell the baker what you need. They’ll review and send you a '
                'price quote to approve before any payment.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              _DateField(
                value: _eventDate,
                earliest: _earliestDate,
                onTap: _pickDate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _servings,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Servings / size',
                  hintText: 'e.g. 20 people, 2 tiers',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _flavor,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Flavour',
                  hintText: 'e.g. red velvet, vanilla',
                  prefixIcon: Icon(Icons.icecream_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _message,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Message on cake (optional)',
                  hintText: 'e.g. Happy Birthday Amina',
                  prefixIcon: Icon(Icons.edit_outlined),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'Other details (optional)',
                  hintText: 'Colours, theme, allergies, references…',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _address,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Delivery address',
                  hintText: 'Where should we deliver?',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
                validator: (v) =>
                    Validators.required(v, field: 'Delivery address'),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Send request',
                icon: Icons.send_outlined,
                isLoading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable field that shows the chosen event date (or a prompt).
class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.earliest,
    required this.onTap,
  });

  final DateTime? value;
  final DateTime earliest;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Event date',
          prefixIcon: const Icon(Icons.event_outlined),
          helperText: 'Earliest: ${Formatters.eventDate(earliest)}',
        ),
        child: Text(
          value == null ? 'Choose a date' : Formatters.eventDate(value!),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: value == null
                    ? Theme.of(context).hintColor
                    : Theme.of(context).colorScheme.onSurface,
              ),
        ),
      ),
    );
  }
}
