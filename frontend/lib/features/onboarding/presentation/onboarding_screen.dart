import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../routes/app_routes.dart';
import '../../../widgets/primary_button.dart';

/// Baker KYC / verification onboarding flow.
///
/// Stub: collects business details and identity documents before a baker can
/// publish products. Steps are placeholders pending the verification API.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Baker verification')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Verify your bakery',
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Complete KYC to start receiving custom orders.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              const _OnboardingStep(
                icon: Icons.storefront_outlined,
                title: 'Business details',
                subtitle: 'Name, location and specialties',
              ),
              const _OnboardingStep(
                icon: Icons.badge_outlined,
                title: 'Identity documents',
                subtitle: 'Upload an ID for verification',
              ),
              const _OnboardingStep(
                icon: Icons.account_balance_outlined,
                title: 'Payout details',
                subtitle: 'Where escrow funds are released',
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Submit for review',
                // TODO: POST to bakerKyc endpoint, then route to baker home.
                onPressed: () => context.goNamed(AppRoutes.bakerHomeName),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingStep extends StatelessWidget {
  const _OnboardingStep({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          // TODO: Navigate into the individual KYC step form.
        },
      ),
    );
  }
}
