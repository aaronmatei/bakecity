import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../widgets/empty_state.dart';
import '../../bakers/domain/baker_profile.dart';
import '../../discovery/application/discovery_controller.dart';
import '../../home/widgets/baker_card.dart';
import '../../home/widgets/product_card.dart';
import '../../products/application/products_controller.dart';
import '../../products/domain/product.dart';

/// Session-only recent searches.
final _recentSearchesProvider = StateProvider<List<String>>((_) => []);

/// Dedicated search screen reached from the home search pill (shared-element
/// hero on the field). Filters products and bakers instantly as the user types.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) => setState(() => _query = v.trim());

  void _remember(String term) {
    final t = term.trim();
    if (t.isEmpty) return;
    final recents = ref.read(_recentSearchesProvider);
    ref.read(_recentSearchesProvider.notifier).state =
        [t, ...recents.where((e) => e != t)].take(8).toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    final products = ref.watch(productsProvider(null)).valueOrNull ?? const [];
    final bakers = ref.watch(nearbyBakersProvider).valueOrNull ?? const [];

    final q = _query.toLowerCase();
    final matchedProducts = q.isEmpty
        ? const <Product>[]
        : products
            .where((p) => p.name.toLowerCase().contains(q))
            .toList();
    final matchedBakers = q.isEmpty
        ? const <BakerProfile>[]
        : bakers
            .where((b) => b.businessName.toLowerCase().contains(q))
            .toList();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Hero(
          tag: 'home-search-bar',
          child: Material(
            color: Colors.transparent,
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: Insets.lg),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.search_rounded,
                      color: cs.onSurfaceVariant, size: 22),
                  const SizedBox(width: Insets.md),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      onChanged: _onChanged,
                      onSubmitted: _remember,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Search cakes, bakers, treats…',
                      ),
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        _onChanged('');
                      },
                      child: Icon(Icons.close_rounded,
                          size: 20, color: cs.onSurfaceVariant),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _query.isEmpty
          ? _RecentAndIdle(
              onPick: (term) {
                _controller.text = term;
                _onChanged(term);
              },
            )
          : _Results(products: matchedProducts, bakers: matchedBakers),
    );
  }
}

class _RecentAndIdle extends ConsumerWidget {
  const _RecentAndIdle({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recents = ref.watch(_recentSearchesProvider);
    const suggestions = [
      'Birthday cake',
      'Cupcakes',
      'Wedding',
      'Cookies',
      'Bread',
      'Custom'
    ];
    return ListView(
      padding: const EdgeInsets.all(Insets.screenH),
      children: [
        if (recents.isNotEmpty) ...[
          Text('Recent', style: context.tt.titleSmall),
          const SizedBox(height: Insets.md),
          Wrap(
            spacing: Insets.sm,
            runSpacing: Insets.sm,
            children: [
              for (final r in recents)
                ActionChip(label: Text(r), onPressed: () => onPick(r)),
            ],
          ),
          const SizedBox(height: Insets.xl),
        ],
        Text('Popular', style: context.tt.titleSmall),
        const SizedBox(height: Insets.md),
        Wrap(
          spacing: Insets.sm,
          runSpacing: Insets.sm,
          children: [
            for (final s in suggestions)
              ActionChip(label: Text(s), onPressed: () => onPick(s)),
          ],
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.products, required this.bakers});
  final List<Product> products;
  final List<BakerProfile> bakers;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty && bakers.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No matches',
        message: 'Try a different cake, treat, or bakery name.',
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - Insets.screenH * 2 - Insets.lg) / 2;
        return ListView(
          padding: const EdgeInsets.all(Insets.screenH),
          children: [
            if (bakers.isNotEmpty) ...[
              Text('Bakers', style: context.tt.titleSmall),
              const SizedBox(height: Insets.md),
              SizedBox(
                height: 196,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: bakers.length,
                  separatorBuilder: (_, __) => const SizedBox(width: Insets.lg),
                  itemBuilder: (_, i) => BakerCard(baker: bakers[i]),
                ),
              ),
              const SizedBox(height: Insets.xl),
            ],
            if (products.isNotEmpty) ...[
              Text('Treats', style: context.tt.titleSmall),
              const SizedBox(height: Insets.md),
              Wrap(
                spacing: Insets.lg,
                runSpacing: Insets.xl,
                children: [
                  for (final p in products)
                    ProductCard(product: p, width: itemWidth),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
