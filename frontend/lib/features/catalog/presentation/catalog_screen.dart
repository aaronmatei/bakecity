import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/press_scale.dart';
import '../../../widgets/skeletons.dart';
import '../../home/widgets/product_card.dart';
import '../../products/application/products_controller.dart';

// (value, label) option lists matching the backend's vocabulary.
const _occasions = [
  ('birthday', 'Birthday'), ('wedding', 'Wedding'), ('anniversary', 'Anniversary'),
  ('graduation', 'Graduation'), ('baby_shower', 'Baby shower'),
  ('gender_reveal', 'Gender reveal'), ('corporate', 'Corporate'), ('generic', 'Everyday'),
];
const _flavors = [
  ('chocolate', 'Chocolate'), ('vanilla', 'Vanilla'), ('red_velvet', 'Red velvet'),
  ('black_forest', 'Black forest'), ('fruit', 'Fruit'), ('carrot', 'Carrot'),
  ('lemon', 'Lemon'), ('coffee', 'Coffee'), ('cheesecake', 'Cheesecake'),
];
const _formats = [
  ('standard', 'Standard'), ('bento', 'Bento'), ('photo', 'Photo'),
  ('tiered', 'Tiered'), ('sheet', 'Sheet'), ('number', 'Number'),
];
const _dietaryOpts = [
  ('eggless', 'Eggless'), ('vegan', 'Vegan'), ('gluten_free', 'Gluten-free'),
  ('sugar_free', 'Sugar-free'), ('halal', 'Halal'),
];
const _sorts = [
  ('top_rated', 'Top rated'), ('best_selling', 'Best selling'),
  ('price_asc', 'Price: low to high'), ('price_desc', 'Price: high to low'),
  ('newest', 'Newest'),
];

/// Catalog results with a category chip row, a Filters bottom-sheet, and a grid
/// of products fed by the composable product search.
class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key, this.initialCategory, this.initialSort});

  final String? initialCategory;
  final String? initialSort;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  late ProductFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = ProductFilter(
      category: widget.initialCategory,
      sort: widget.initialSort ?? 'top_rated',
      limit: 60,
    );
  }

  void _set(ProductFilter f) => setState(() => _filter = f);

  int get _activeCount {
    var n = 0;
    if (_filter.occasion != null) n++;
    if (_filter.flavor != null) n++;
    if (_filter.format != null) n++;
    n += _filter.dietary.length;
    if (_filter.minPrice != null || _filter.maxPrice != null) n++;
    if (_filter.minRating != null) n++;
    if (_filter.onOffer == true) n++;
    return n;
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<ProductFilter>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(filter: _filter),
    );
    if (result != null) _set(result);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final products = ref.watch(productSearchProvider(_filter));
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Browse')),
      body: Column(
        children: [
          // Category chips.
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Insets.screenH),
              itemCount: categories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: Insets.sm),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _Chip(
                    label: 'All',
                    selected: _filter.category == null,
                    onTap: () => _set(_filter.copyWith(
                        clearCategory: true, clearCakeAxes: true)),
                  );
                }
                final c = categories[i - 1];
                final on = _filter.category == c.slug;
                return _Chip(
                  label: c.name,
                  selected: on,
                  onTap: () => _set(on
                      ? _filter.copyWith(clearCategory: true, clearCakeAxes: true)
                      : _filter.copyWith(category: c.slug, clearCakeAxes: true)),
                );
              },
            ),
          ),
          // Sort + Filters bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Insets.screenH, Insets.sm, Insets.screenH, Insets.sm),
            child: Row(
              children: [
                Expanded(child: _SortChip(filter: _filter, onChanged: _set)),
                const SizedBox(width: Insets.sm),
                PressScale(
                  onTap: _openFilters,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: Insets.lg, vertical: 10),
                    decoration: BoxDecoration(
                      color: _activeCount > 0 ? cs.primary : cs.surface,
                      borderRadius: BorderRadius.circular(40),
                      border: Border.all(
                          color: _activeCount > 0 ? cs.primary : cs.outlineVariant),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tune,
                            size: 16,
                            color: _activeCount > 0 ? cs.onPrimary : cs.onSurface),
                        const SizedBox(width: 6),
                        Text(
                          _activeCount > 0 ? 'Filters ($_activeCount)' : 'Filters',
                          style: context.tt.labelLarge?.copyWith(
                              color: _activeCount > 0 ? cs.onPrimary : cs.onSurface,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: products.when(
              loading: () => LayoutBuilder(
                builder: (context, c) {
                  final w = (c.maxWidth - Insets.screenH * 2 - Insets.lg) / 2;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(Insets.screenH),
                    child: Wrap(
                      spacing: Insets.lg,
                      runSpacing: Insets.xl,
                      children: List.generate(
                          6, (_) => ProductCardSkeleton(width: w)),
                    ),
                  );
                },
              ),
              error: (e, _) => AppErrorView(
                message: e.toString(),
                onRetry: () => ref.invalidate(productSearchProvider(_filter)),
              ),
              data: (list) {
                if (list.isEmpty) {
                  return const EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'No treats match',
                    message: 'Try removing a filter or widening your search.',
                  );
                }
                return LayoutBuilder(
                  builder: (context, c) {
                    final w =
                        (c.maxWidth - Insets.screenH * 2 - Insets.lg) / 2;
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(Insets.screenH),
                      child: Wrap(
                        spacing: Insets.lg,
                        runSpacing: Insets.xl,
                        children: [
                          for (final p in list)
                            ProductCard(
                              product: p,
                              width: w,
                              discountPct: p.isOnOffer ? p.discountPct : null,
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({required this.filter, required this.onChanged});
  final ProductFilter filter;
  final ValueChanged<ProductFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final label = _sorts.firstWhere((s) => s.$1 == filter.sort,
        orElse: () => _sorts.first).$2;
    return PopupMenuButton<String>(
      onSelected: (v) => onChanged(filter.copyWith(sort: v)),
      itemBuilder: (_) =>
          [for (final s in _sorts) PopupMenuItem(value: s.$1, child: Text(s.$2))],
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: Insets.lg, vertical: 10),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label, style: context.tt.labelLarge),
            Icon(Icons.arrow_drop_down, size: 18, color: cs.onSurfaceVariant),
          ],
        ),
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
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
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

/// The advanced filter bottom-sheet. Cake axes show only for the Cakes category.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filter});
  final ProductFilter filter;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ProductFilter _draft = widget.filter;

  bool get _isCakes => _draft.category == 'cakes';

  /// Rebuilds the draft with specific cake axes (each may be set to null),
  /// since copyWith can't distinguish "unchanged" from "clear this one".
  ProductFilter _axes({String? occasion, String? flavor, String? format}) =>
      ProductFilter(
        category: _draft.category,
        occasion: occasion,
        flavor: flavor,
        format: format,
        dietary: _draft.dietary,
        minPrice: _draft.minPrice,
        maxPrice: _draft.maxPrice,
        minRating: _draft.minRating,
        onOffer: _draft.onOffer,
        sort: _draft.sort,
        limit: _draft.limit,
      );

  @override
  Widget build(BuildContext context) {
    final isCakes = _isCakes;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        children: [
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(
                  Insets.screenH, 0, Insets.screenH, Insets.lg),
              children: [
                Text('Filters', style: context.tt.titleLarge),
                if (isCakes) ...[
                  _group('Occasion'),
                  _single(
                      _occasions,
                      _draft.occasion,
                      (v) => setState(() => _draft = _axes(
                          occasion: v,
                          flavor: _draft.flavor,
                          format: _draft.format))),
                  _group('Flavour'),
                  _single(
                      _flavors,
                      _draft.flavor,
                      (v) => setState(() => _draft = _axes(
                          occasion: _draft.occasion,
                          flavor: v,
                          format: _draft.format))),
                  _group('Format'),
                  _single(
                      _formats,
                      _draft.format,
                      (v) => setState(() => _draft = _axes(
                          occasion: _draft.occasion,
                          flavor: _draft.flavor,
                          format: v))),
                ],
                _group('Dietary'),
                _multi(),
                _group('Price (KES)'),
                _priceBrackets(),
                _group('Rating'),
                _ratingRow(),
                const SizedBox(height: Insets.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _draft.onOffer == true,
                  onChanged: (v) => setState(() =>
                      _draft = _draft.copyWith(onOffer: v, clearOffer: !v)),
                  title: const Text('On offer only'),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(
                Insets.screenH, Insets.sm, Insets.screenH, Insets.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _draft = ProductFilter(
                        category: _draft.category,
                        sort: _draft.sort,
                        limit: _draft.limit)),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: Insets.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _draft),
                    child: const Text('Show results'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(String t) => Padding(
        padding: const EdgeInsets.only(top: Insets.lg, bottom: Insets.sm),
        child: Text(t, style: context.tt.titleSmall),
      );

  Widget _single(List<(String, String)> opts, String? value,
      ValueChanged<String?> onPick) {
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final o in opts)
          _Chip(
            label: o.$2,
            selected: value == o.$1,
            onTap: () => onPick(value == o.$1 ? null : o.$1),
          ),
      ],
    );
  }

  Widget _multi() {
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final o in _dietaryOpts)
          _Chip(
            label: o.$2,
            selected: _draft.dietary.contains(o.$1),
            onTap: () {
              final next = List<String>.from(_draft.dietary);
              next.contains(o.$1) ? next.remove(o.$1) : next.add(o.$1);
              setState(() => _draft = _draft.copyWith(dietary: next));
            },
          ),
      ],
    );
  }

  Widget _priceBrackets() {
    const brackets = [
      ('Under 500', null, 500.0),
      ('500–2k', 500.0, 2000.0),
      ('2k–5k', 2000.0, 5000.0),
      ('Over 5k', 5000.0, null),
    ];
    return Wrap(
      spacing: Insets.sm,
      runSpacing: Insets.sm,
      children: [
        for (final (label, lo, hi) in brackets)
          _Chip(
            label: label,
            selected: _draft.minPrice == lo && _draft.maxPrice == hi,
            onTap: () {
              final on = _draft.minPrice == lo && _draft.maxPrice == hi;
              setState(() => _draft = on
                  ? _draft.copyWith(clearPrice: true)
                  : _draft.copyWith(minPrice: lo, maxPrice: hi));
            },
          ),
      ],
    );
  }

  Widget _ratingRow() {
    return Wrap(
      spacing: Insets.sm,
      children: [
        for (final r in [4.0, 4.5])
          _Chip(
            label: '${r.toStringAsFixed(1)}★ +',
            selected: _draft.minRating == r,
            onTap: () => setState(() => _draft = _draft.minRating == r
                ? _draft.copyWith(clearRating: true)
                : _draft.copyWith(minRating: r)),
          ),
      ],
    );
  }
}
