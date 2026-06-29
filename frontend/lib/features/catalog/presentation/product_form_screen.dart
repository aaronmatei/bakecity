import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/validators.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../widgets/primary_button.dart';
import '../../products/application/products_controller.dart';
import '../../products/domain/product.dart';

/// Add or edit a product. [product] null = create; otherwise edit.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, required this.bakerId, this.product});

  final String bakerId;
  final Product? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _leadTime;
  String? _categoryId;
  late bool _available;
  bool _saving = false;

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _title = TextEditingController(text: p?.name ?? '');
    _description = TextEditingController(text: p?.description ?? '');
    _price = TextEditingController(
        text: p != null ? (p.basePriceCents / 100).toStringAsFixed(0) : '');
    _leadTime = TextEditingController(text: '${p?.leadTimeDays ?? 1}');
    _categoryId = p?.categoryId;
    _available = p?.isAvailable ?? true;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _leadTime.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ctrl = ref.read(catalogControllerProvider);
    final priceCents = (double.parse(_price.text.trim()) * 100).round();
    final lead = int.tryParse(_leadTime.text.trim()) ?? 1;
    try {
      if (_isEdit) {
        await ctrl.updateProduct(
          widget.product!.id,
          title: _title.text.trim(),
          description: _description.text.trim(),
          categoryId: _categoryId,
          basePriceCents: priceCents,
          leadTimeDays: lead,
          active: _available,
        );
      } else {
        await ctrl.createProduct(
          title: _title.text.trim(),
          categoryId: _categoryId,
          description: _description.text.trim(),
          basePriceCents: priceCents,
          leadTimeDays: lead,
        );
      }
      ref.invalidate(bakerManageProductsProvider(widget.bakerId));
      messenger.showSnackBar(
        SnackBar(content: Text(_isEdit ? 'Product updated.' : 'Product added.')),
      );
      navigator.pop();
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'Add product')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(Insets.screenH),
            children: [
              TextFormField(
                controller: _title,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Product name',
                  prefixIcon: Icon(Icons.cake_outlined),
                ),
                validator: (v) => Validators.required(v, field: 'Product name'),
              ),
              const SizedBox(height: Insets.lg),
              DropdownButtonFormField<String?>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Uncategorised')),
                  for (final c in categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: Insets.lg),
              TextFormField(
                controller: _description,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What makes this treat special?',
                  prefixIcon: Icon(Icons.notes_outlined),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: Insets.lg),
              TextFormField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Starting price (KES)',
                  prefixIcon: Icon(Icons.sell_outlined),
                ),
                validator: (v) {
                  final n = double.tryParse((v ?? '').trim());
                  if (n == null || n <= 0) return 'Enter a price above 0';
                  return null;
                },
              ),
              const SizedBox(height: Insets.lg),
              TextFormField(
                controller: _leadTime,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Lead time (days)',
                  helperText: 'How much notice you need for this item',
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n < 0) return 'Enter a whole number';
                  return null;
                },
              ),
              if (_isEdit) ...[
                const SizedBox(height: Insets.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _available,
                  onChanged: (v) => setState(() => _available = v),
                  secondary: const Icon(Icons.visibility_outlined),
                  title: const Text('Available'),
                  subtitle: const Text('Customers can see and order this'),
                ),
              ],
              const SizedBox(height: Insets.xl),
              PrimaryButton(
                label: _isEdit ? 'Save changes' : 'Add product',
                icon: Icons.check,
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
