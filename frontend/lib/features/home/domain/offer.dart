import 'package:flutter/material.dart';

/// A promotional offer shown in the home carousel. There's no promotions
/// backend yet, so these come from a small curated list ([curatedOffers]);
/// swap the provider for an API call when one exists.
class Offer {
  const Offer({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.imageUrl,
    this.categorySlug,
  });

  final String id;
  final String title;
  final String subtitle;

  /// Short badge copy, e.g. "-15%" or "New".
  final String badge;
  final String? imageUrl;

  /// Where tapping the offer should filter discovery, if anywhere.
  final String? categorySlug;
}

/// Curated launch offers. Imagery falls back to art-directed gradient tiles
/// when [imageUrl] is null, so the carousel always looks intentional.
const List<Offer> curatedOffers = [
  Offer(
    id: 'wedding',
    title: 'Wedding season is here',
    subtitle: 'Book a tiered cake and save this week',
    badge: '-15%',
    categorySlug: 'wedding',
    imageUrl: 'https://loremflickr.com/1000/520/wedding,cake?lock=2201',
  ),
  Offer(
    id: 'cupcakes',
    title: 'Cupcake bundles',
    subtitle: 'A dozen handcrafted cupcakes, freshly baked',
    badge: '-20%',
    categorySlug: 'cupcakes',
    imageUrl: 'https://loremflickr.com/1000/520/cupcakes?lock=2202',
  ),
  Offer(
    id: 'custom',
    title: 'Design your dream cake',
    subtitle: 'Custom orders from top-rated local bakers',
    badge: 'New',
    categorySlug: 'custom',
    imageUrl: 'https://loremflickr.com/1000/520/birthday,cake?lock=2203',
  ),
];

/// Deterministic warm gradient per offer, used behind the copy.
LinearGradient offerGradient(int index, ColorScheme cs) {
  final palettes = <List<Color>>[
    [cs.primary, cs.secondary],
    [cs.secondary, cs.primary],
    [cs.primary, cs.tertiary],
  ];
  final pair = palettes[index % palettes.length];
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [pair[0], pair[1]],
  );
}
