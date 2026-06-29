import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/validators.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../services/upload_service.dart';
import '../../../widgets/network_photo.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/primary_button.dart';
import '../../products/application/products_controller.dart';
import '../../products/domain/product.dart';

const _occasions = ['birthday', 'wedding', 'anniversary', 'graduation', 'baby_shower', 'gender_reveal', 'corporate', 'generic'];
const _flavors = ['chocolate', 'vanilla', 'red_velvet', 'black_forest', 'fruit', 'carrot', 'lemon', 'coffee', 'cheesecake'];
const _formats = ['standard', 'bento', 'photo', 'tiered', 'sheet', 'number'];
const _dietaryOpts = ['eggless', 'vegan', 'gluten_free', 'sugar_free', 'halal'];

String _pretty(String s) {
  final w = s.replaceAll('_', ' ');
  return w[0].toUpperCase() + w.substring(1);
}

/// One editable weight/serving row in the sizes editor.
class _SizeRow {
  _SizeRow({String label = '', String serves = '', String price = ''})
      : label = TextEditingController(text: label),
        serves = TextEditingController(text: serves),
        price = TextEditingController(text: price);
  final TextEditingController label;
  final TextEditingController serves;
  final TextEditingController price;
  void dispose() {
    label.dispose();
    serves.dispose();
    price.dispose();
  }
}

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
  late final TextEditingController _discount;
  String? _categoryId;
  late bool _available;
  late bool _isOnOffer;
  String? _occasion;
  String? _flavor;
  String? _format;
  late Set<String> _dietary;
  late List<_SizeRow> _sizes;
  String? _newImageMediaId;
  bool _uploadingImage = false;
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
    _discount = TextEditingController(text: '${p?.discountPct ?? 10}');
    _categoryId = p?.categoryId;
    _available = p?.isAvailable ?? true;
    _isOnOffer = p?.isOnOffer ?? false;
    _occasion = p?.cakeOccasion;
    _flavor = p?.cakeFlavor;
    _format = p?.cakeFormat;
    _dietary = {...?p?.dietary};
    _sizes = [
      for (final s in p?.sizes ?? const <ProductSize>[])
        _SizeRow(
            label: s.label,
            serves: s.serves?.toString() ?? '',
            price: (s.priceCents / 100).toStringAsFixed(0)),
    ];
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _leadTime.dispose();
    _discount.dispose();
    for (final r in _sizes) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    setState(() => _uploadingImage = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final id = await ref
          .read(uploadServiceProvider)
          .pickAndUpload(kind: MediaKind.product);
      if (id != null) setState(() => _newImageMediaId = id);
    } on AppException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  bool _isCakes(List<Category> cats) {
    if (_categoryId == null) return false;
    final c = cats.where((x) => x.id == _categoryId);
    return c.isNotEmpty && c.first.slug == 'cakes';
  }

  List<Map<String, dynamic>> _buildSizes() {
    final out = <Map<String, dynamic>>[];
    for (final r in _sizes) {
      final label = r.label.text.trim();
      final price = double.tryParse(r.price.text.trim());
      if (label.isEmpty || price == null || price <= 0) continue;
      final serves = int.tryParse(r.serves.text.trim());
      out.add({
        'label': label,
        if (serves != null) 'serves': serves,
        'price': price,
      });
    }
    return out;
  }

  Future<void> _save(bool cakes) async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ctrl = ref.read(catalogControllerProvider);
    final priceCents = (double.parse(_price.text.trim()) * 100).round();
    final lead = int.tryParse(_leadTime.text.trim()) ?? 1;
    final discount = _isOnOffer ? int.tryParse(_discount.text.trim()) : null;
    final sizes = _buildSizes();
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
          dietary: _dietary.toList(),
          isOnOffer: _isOnOffer,
          discountPct: discount,
          cakeOccasion: cakes ? _occasion : null,
          cakeFlavor: cakes ? _flavor : null,
          cakeFormat: cakes ? _format : null,
          sizes: sizes,
          imageMediaIds:
              _newImageMediaId != null ? [_newImageMediaId!] : null,
        );
      } else {
        await ctrl.createProduct(
          title: _title.text.trim(),
          categoryId: _categoryId,
          description: _description.text.trim(),
          basePriceCents: priceCents,
          leadTimeDays: lead,
          dietary: _dietary.toList(),
          isOnOffer: _isOnOffer,
          discountPct: discount,
          cakeOccasion: cakes ? _occasion : null,
          cakeFlavor: cakes ? _flavor : null,
          cakeFormat: cakes ? _format : null,
          sizes: sizes,
          imageMediaIds:
              _newImageMediaId != null ? [_newImageMediaId!] : const [],
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
    final cakes = _isCakes(categories);
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'Add product')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(Insets.screenH),
            children: [
              _imageSection(),
              const SizedBox(height: Insets.lg),
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
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
                validator: (v) {
                  final n = int.tryParse((v ?? '').trim());
                  if (n == null || n < 0) return 'Enter a whole number';
                  return null;
                },
              ),

              // Cake attributes.
              if (cakes) ...[
                _heading('Cake details'),
                _singleChips('Occasion', _occasions, _occasion,
                    (v) => setState(() => _occasion = v)),
                const SizedBox(height: Insets.md),
                _singleChips('Flavour', _flavors, _flavor,
                    (v) => setState(() => _flavor = v)),
                const SizedBox(height: Insets.md),
                _singleChips('Format', _formats, _format,
                    (v) => setState(() => _format = v)),
              ],

              _heading('Dietary'),
              Wrap(
                spacing: Insets.sm,
                runSpacing: Insets.sm,
                children: [
                  for (final d in _dietaryOpts)
                    _Chip(
                      label: _pretty(d),
                      selected: _dietary.contains(d),
                      onTap: () => setState(() => _dietary.contains(d)
                          ? _dietary.remove(d)
                          : _dietary.add(d)),
                    ),
                ],
              ),

              // Sizes editor.
              _heading('Sizes (optional)'),
              for (int i = 0; i < _sizes.length; i++) _sizeRow(i),
              const SizedBox(height: Insets.sm),
              OutlinedButton.icon(
                onPressed: () => setState(() => _sizes.add(_SizeRow())),
                icon: const Icon(Icons.add),
                label: const Text('Add size'),
              ),

              const SizedBox(height: Insets.lg),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isOnOffer,
                onChanged: (v) => setState(() => _isOnOffer = v),
                secondary: const Icon(Icons.local_offer_outlined),
                title: const Text('On offer'),
              ),
              if (_isOnOffer)
                TextFormField(
                  controller: _discount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Discount (%)',
                    prefixIcon: Icon(Icons.percent_outlined),
                  ),
                ),
              if (_isEdit) ...[
                const SizedBox(height: Insets.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _available,
                  onChanged: (v) => setState(() => _available = v),
                  secondary: const Icon(Icons.visibility_outlined),
                  title: const Text('Available'),
                ),
              ],
              const SizedBox(height: Insets.xl),
              PrimaryButton(
                label: _isEdit ? 'Save changes' : 'Add product',
                icon: Icons.check,
                isLoading: _saving,
                onPressed: _saving ? null : () => _save(cakes),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imageSection() {
    final cs = context.cs;
    final existing = widget.product?.imageUrls ?? const <String>[];
    final hasExisting = existing.isNotEmpty;
    return PressScale(
      onTap: _uploadingImage ? null : _pickImage,
      child: Container(
        height: 170,
        width: double.infinity,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: Radii.cardBorder,
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_newImageMediaId == null && hasExisting)
              NetworkPhoto(
                  url: existing.first,
                  height: 170,
                  width: double.infinity,
                  radius: 0)
            else if (_newImageMediaId != null)
              Center(
                  child: Icon(Icons.check_circle,
                      size: 44, color: context.bake.success))
            else
              Center(
                  child: Icon(Icons.add_a_photo_outlined,
                      size: 36, color: cs.onSurfaceVariant)),
            if (_uploadingImage)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: Colors.black.withValues(alpha: 0.45),
                child: Text(
                  _newImageMediaId != null
                      ? 'New photo ready — tap to change'
                      : hasExisting
                          ? 'Tap to replace photo'
                          : 'Tap to add a photo',
                  textAlign: TextAlign.center,
                  style: context.tt.labelMedium?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heading(String t) => Padding(
        padding: const EdgeInsets.only(top: Insets.xl, bottom: Insets.sm),
        child: Text(t, style: context.tt.titleMedium),
      );

  Widget _singleChips(String label, List<String> opts, String? value,
      ValueChanged<String?> onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: context.tt.bodySmall
                ?.copyWith(color: context.cs.onSurfaceVariant)),
        const SizedBox(height: Insets.xs),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: [
            for (final o in opts)
              _Chip(
                label: _pretty(o),
                selected: value == o,
                onTap: () => onPick(value == o ? null : o),
              ),
          ],
        ),
      ],
    );
  }

  Widget _sizeRow(int i) {
    final r = _sizes[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: r.label,
              decoration: const InputDecoration(labelText: 'Label', isDense: true),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            flex: 2,
            child: TextField(
              controller: r.serves,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Serves', isDense: true),
            ),
          ),
          const SizedBox(width: Insets.sm),
          Expanded(
            flex: 3,
            child: TextField(
              controller: r.price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              decoration: const InputDecoration(labelText: 'KES', isDense: true),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, color: context.cs.onSurfaceVariant),
            onPressed: () => setState(() {
              _sizes.removeAt(i).dispose();
            }),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return PressScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Insets.md, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cs.primary : cs.surface,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: selected ? cs.primary : cs.outlineVariant),
        ),
        child: Text(label,
            style: context.tt.labelLarge?.copyWith(
                color: selected ? cs.onPrimary : cs.onSurface,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}
