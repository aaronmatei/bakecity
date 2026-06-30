import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../routes/app_routes.dart';
import '../../../widgets/primary_button.dart';

/// The unauthenticated landing screen: a warm, branded hero with the two entry
/// points (order or sell) plus a path to log in. Mirrors the marketing design —
/// "Fresh from your neighbourhood bakers".
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              cs.primaryContainer.withValues(alpha: 0.55),
              cs.surface,
            ],
            stops: const [0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: Insets.xl, vertical: Insets.xxl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BrandMark(),
                    const SizedBox(height: Insets.xl),
                    Text(
                      'Fresh from your\nneighbourhood bakers',
                      textAlign: TextAlign.center,
                      style: context.tt.displaySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: Insets.md),
                    Text(
                      'Order cakes, bread and pastries baked today — '
                      'delivered warm or ready to collect.',
                      textAlign: TextAlign.center,
                      style: context.tt.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: Insets.xxl),
                    PrimaryButton(
                      label: 'Create your account',
                      icon: Icons.shopping_bag_outlined,
                      onPressed: () => context.goNamed(AppRoutes.registerName),
                    ),
                    const SizedBox(height: Insets.md),
                    OutlinedButton.icon(
                      onPressed: () => context.goNamed(
                        AppRoutes.registerName,
                        queryParameters: {'role': UserRole.baker.name},
                      ),
                      icon: const Icon(Icons.storefront_outlined),
                      label: const Text('I bake — sell on BakeCity'),
                    ),
                    const SizedBox(height: Insets.xl),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account?',
                            style: context.tt.bodyMedium
                                ?.copyWith(color: cs.onSurfaceVariant)),
                        TextButton(
                          onPressed: () =>
                              context.goNamed(AppRoutes.loginName),
                          child: const Text('Log in'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded app icon tile + wordmark.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final cs = context.cs;
    return Column(
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(Radii.cardLg),
            boxShadow: context.bake.cardShadow,
          ),
          child: Icon(Icons.cake_rounded, size: 44, color: cs.onPrimary),
        ),
        const SizedBox(height: Insets.md),
        Text(
          AppConstants.appName,
          style: context.tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}
