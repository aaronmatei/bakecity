import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/formatters.dart';
import '../../../core/helpers/validators.dart';
import '../../../routes/app_routes.dart';
import '../../../services/upload_service.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/primary_button.dart';
import '../../products/application/products_controller.dart';
import '../../products/domain/product.dart';
import '../application/orders_controller.dart';

/// An image the customer picked to attach as a design reference. Bytes are held
/// in memory for the preview, then uploaded once the order exists.
class _Reference {
  const _Reference({required this.bytes, required this.contentType});
  final Uint8List bytes;
  final String contentType;
}

/// Collects the details for a custom-order request against a product and sends
/// it to the baker as a quote request (the first step of the escrow lifecycle).
class OrderRequestScreen extends ConsumerWidget {
  const OrderRequestScreen({
    super.key,
    required this.productId,
    this.initialSize,
  });

  final String productId;

  /// The size the customer chose on the product detail screen, if any.
  final String? initialSize;

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
          data: (p) => _OrderRequestForm(product: p, initialSize: initialSize),
        ),
      ),
    );
  }
}

class _OrderRequestForm extends ConsumerStatefulWidget {
  const _OrderRequestForm({required this.product, this.initialSize});

  final Product product;
  final String? initialSize;

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

  final List<_Reference> _references = [];
  static const int _maxReferences = 5;

  DateTime? _eventDate;
  String _fulfillment = 'delivery';
  bool _submitting = false;
  bool _pickingPhoto = false;

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

  Future<void> _addPhoto() async {
    if (_references.length >= _maxReferences) return;
    setState(() => _pickingPhoto = true);
    try {
      final file = await ref.read(uploadServiceProvider).pickImage();
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _references.add(_Reference(
            bytes: bytes,
            contentType: file.mimeType ?? 'image/jpeg',
          ));
        });
      }
    } finally {
      if (mounted) setState(() => _pickingPhoto = false);
    }
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
            fulfillment: _fulfillment,
            deliveryAddress:
                _fulfillment == 'delivery' ? _address.text.trim() : '',
            specs: _buildSpecs(),
          );
      // Attach reference photos to the new order. Best-effort: the order is
      // already placed, so a failed upload must not block the customer.
      final failedUploads = await _uploadReferences(order.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            failedUploads == 0
                ? 'Request sent — the baker will quote you.'
                : 'Request sent. $failedUploads photo(s) couldn’t upload.',
          ),
        ),
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

  /// Uploads the picked references against the order; returns how many failed.
  Future<int> _uploadReferences(String orderId) async {
    final uploader = ref.read(uploadServiceProvider);
    var failed = 0;
    for (final reference in _references) {
      try {
        await uploader.uploadBytes(
          bytes: reference.bytes,
          contentType: reference.contentType,
          kind: MediaKind.reference,
          orderId: orderId,
        );
      } catch (_) {
        failed++;
      }
    }
    return failed;
  }

  /// Collects the non-empty custom fields into the backend's key/value specs.
  Map<String, String> _buildSpecs() {
    final specs = <String, String>{};
    void add(String key, TextEditingController c) {
      final v = c.text.trim();
      if (v.isNotEmpty) specs[key] = v;
    }

    // The size chosen on the product page (e.g. "1.5kg · serves 12").
    final size = widget.initialSize?.trim();
    if (size != null && size.isNotEmpty) specs['size'] = size;

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
                    widget.initialSize != null
                        ? 'Size: ${widget.initialSize} • lead time '
                            '${p.leadTimeDays} day(s)'
                        : 'From ${Formatters.currencyFromCents(p.basePriceCents)} • '
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
              const SizedBox(height: 20),
              Text('Reference photos (optional)',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Share inspiration so the baker can match your vision.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _references.length +
                      (_references.length < _maxReferences ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    if (i == _references.length) {
                      return _AddPhotoButton(
                        busy: _pickingPhoto,
                        onTap: _pickingPhoto ? null : _addPhoto,
                      );
                    }
                    return _ReferenceThumb(
                      bytes: _references[i].bytes,
                      onRemove: () =>
                          setState(() => _references.removeAt(i)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'delivery',
                      label: Text('Delivery'),
                      icon: Icon(Icons.delivery_dining_outlined)),
                  ButtonSegment(
                      value: 'pickup',
                      label: Text('Pickup'),
                      icon: Icon(Icons.storefront_outlined)),
                ],
                selected: {_fulfillment},
                onSelectionChanged: (s) =>
                    setState(() => _fulfillment = s.first),
              ),
              const SizedBox(height: 8),
              Text(
                _fulfillment == 'delivery'
                    ? 'The baker will add a courier fee to your quote.'
                    : 'You\'ll collect the order from the baker — no courier fee.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (_fulfillment == 'delivery') ...[
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
              ],
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

/// A reference image preview with a remove button.
class _ReferenceThumb extends StatelessWidget {
  const _ReferenceThumb({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            width: 96,
            height: 96,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black54,
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

/// The "add a reference photo" tile.
class _AddPhotoButton extends StatelessWidget {
  const _AddPhotoButton({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        alignment: Alignment.center,
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(height: 4),
                  Text('Add', style: theme.textTheme.bodySmall),
                ],
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
