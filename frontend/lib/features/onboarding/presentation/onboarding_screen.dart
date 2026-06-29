import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/helpers/validators.dart';
import '../../../routes/app_routes.dart';
import '../../../services/upload_service.dart';
import '../../../widgets/app_error_view.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/primary_button.dart';
import '../../bakers/domain/my_baker_profile.dart';
import '../../discovery/application/discovery_controller.dart';
import '../application/onboarding_controller.dart';

/// A locally-picked identity document awaiting upload. [mediaId] is set once it
/// has been uploaded, so a retried submission doesn't re-upload it.
class _KycDoc {
  _KycDoc({required this.bytes, required this.contentType});
  final Uint8List bytes;
  final String contentType;
  String? mediaId;
}

/// Baker KYC / verification onboarding flow.
///
/// Collects the baker's business details and submits them for admin review.
/// The screen reflects KYC state: a baker fills in (or fixes) their details
/// while [KycStatus.pending] / [KycStatus.rejected], sees an "under review"
/// state once [KycStatus.submitted], and a "verified" state once approved.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Baker verification')),
      body: SafeArea(
        child: switch (state) {
          AsyncLoading() => const LoadingIndicator(label: 'Loading your bakery…'),
          AsyncError(:final error) => AppErrorView(
              message: error is AppException ? error.message : '$error',
              onRetry: () =>
                  ref.read(onboardingControllerProvider.notifier).refresh(),
            ),
          AsyncData(:final value) => _OnboardingBody(profile: value),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// Routes the loaded profile to the right view: the details form when the baker
/// still needs to submit, or a status card once they have.
class _OnboardingBody extends StatelessWidget {
  const _OnboardingBody({required this.profile});

  final MyBakerProfile? profile;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    if (p == null || p.needsSubmission) {
      return _OnboardingForm(initial: p);
    }
    return _StatusView(profile: p);
  }
}

/// The KYC details form. Pre-fills from [initial] when the baker already has a
/// profile (the common case — a profile is provisioned at signup).
class _OnboardingForm extends ConsumerStatefulWidget {
  const _OnboardingForm({this.initial});

  final MyBakerProfile? initial;

  @override
  ConsumerState<_OnboardingForm> createState() => _OnboardingFormState();
}

class _OnboardingFormState extends ConsumerState<_OnboardingForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _businessName;
  late final TextEditingController _bio;
  late final TextEditingController _deliveryRadius;
  late final TextEditingController _leadTime;
  late final TextEditingController _capacity;
  late final TextEditingController _lat;
  late final TextEditingController _lng;

  final List<_KycDoc> _kycDocs = [];
  static const int _maxKycDocs = 4;
  bool _pickingDoc = false;
  bool _locating = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _businessName = TextEditingController(text: p?.businessName ?? '');
    _bio = TextEditingController(text: p?.bio ?? '');
    _deliveryRadius =
        TextEditingController(text: _numText(p?.deliveryRadiusKm ?? 10));
    _leadTime = TextEditingController(text: '${p?.leadTimeDays ?? 1}');
    _capacity = TextEditingController(text: '${p?.dailyCapacity ?? 10}');
    _lat = TextEditingController(text: p?.lat != null ? '${p!.lat}' : '');
    _lng = TextEditingController(text: p?.lng != null ? '${p!.lng}' : '');
  }

  static String _numText(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : '$v';

  @override
  void dispose() {
    _businessName.dispose();
    _bio.dispose();
    _deliveryRadius.dispose();
    _leadTime.dispose();
    _capacity.dispose();
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _locating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      ref.invalidate(userLocationProvider);
      final loc = await ref.read(userLocationProvider.future);
      if (loc == null) {
        messenger.showSnackBar(const SnackBar(
          content: Text(
              'Couldn\'t get your location. Enable location access or enter it manually.'),
        ));
        return;
      }
      setState(() {
        _lat.text = loc.latitude.toStringAsFixed(6);
        _lng.text = loc.longitude.toStringAsFixed(6);
      });
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _addDoc() async {
    if (_kycDocs.length >= _maxKycDocs) return;
    setState(() => _pickingDoc = true);
    try {
      final file = await ref.read(uploadServiceProvider).pickImage();
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() => _kycDocs.add(
              _KycDoc(bytes: bytes, contentType: file.mimeType ?? 'image/jpeg'),
            ));
      }
    } finally {
      if (mounted) setState(() => _pickingDoc = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    if (_kycDocs.isEmpty) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Add at least one identity document to verify your bakery.'),
      ));
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _submitting = true);
    try {
      // Upload any not-yet-uploaded documents first (owner-scoped, no order).
      // The backend rejects the submission unless a document is on file.
      final uploader = ref.read(uploadServiceProvider);
      for (final doc in _kycDocs) {
        doc.mediaId ??= await uploader.uploadBytes(
          bytes: doc.bytes,
          contentType: doc.contentType,
          kind: MediaKind.kyc,
        );
      }
      await ref.read(onboardingControllerProvider.notifier).submit(
            businessName: _businessName.text.trim(),
            bio: _bio.text.trim(),
            deliveryRadiusKm: double.parse(_deliveryRadius.text.trim()),
            leadTimeDays: int.parse(_leadTime.text.trim()),
            dailyCapacity: int.parse(_capacity.text.trim()),
            lat: _parseOptional(_lat.text),
            lng: _parseOptional(_lng.text),
          );
      // On success the provider state advances to "under review" and this form
      // is replaced by the status view.
    } on AppException catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  static double? _parseOptional(String value) {
    final t = value.trim();
    return t.isEmpty ? null : double.tryParse(t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rejected = widget.initial?.isRejected ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Verify your bakery', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                'Complete your business details to submit for review. Once a '
                'reviewer approves your bakery you can publish products and '
                'receive orders.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (rejected) ...[
                const SizedBox(height: 16),
                _Banner(
                  icon: Icons.error_outline,
                  color: theme.colorScheme.error,
                  text: 'Your previous submission was rejected. Update your '
                      'details and submit again.',
                ),
              ],
              const SizedBox(height: 24),
              TextFormField(
                controller: _businessName,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Bakery name',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (v) => Validators.required(v, field: 'Bakery name'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bio,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  labelText: 'About your bakery',
                  hintText: 'Specialties, experience, anything customers '
                      'should know',
                  prefixIcon: Icon(Icons.info_outline),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),
              Text('Order settings', style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              TextFormField(
                controller: _deliveryRadius,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Delivery radius (km)',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                validator: (v) => _positiveNumber(v, field: 'Delivery radius'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _leadTime,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Lead time (days)',
                  helperText: 'Minimum notice you need before an event date',
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
                validator: (v) => _positiveInt(v, field: 'Lead time'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _capacity,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Daily order capacity',
                  helperText: 'How many orders you can take per day',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
                validator: (v) => _positiveInt(v, field: 'Daily capacity'),
              ),
              const SizedBox(height: 24),
              Text('Location', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Pin your bakery so nearby customers can find you. This is '
                'required so you show up in distance searches.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _locating ? null : _useCurrentLocation,
                icon: _locating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
                label: Text(
                    _locating ? 'Getting location…' : 'Use my current location'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _lat,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Latitude'),
                      validator: (v) => _coordValidator(v, field: 'Latitude'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _lng,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(labelText: 'Longitude'),
                      validator: (v) => _coordValidator(v, field: 'Longitude'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Identity documents', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Upload a clear photo of your national ID or business permit so '
                'we can verify you. At least one is required.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _kycDocs.length +
                      (_kycDocs.length < _maxKycDocs ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    if (i == _kycDocs.length) {
                      return _AddDocButton(
                        busy: _pickingDoc,
                        onTap: _pickingDoc ? null : _addDoc,
                      );
                    }
                    return _DocThumb(
                      bytes: _kycDocs[i].bytes,
                      onRemove: _submitting
                          ? null
                          : () => setState(() => _kycDocs.removeAt(i)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              PrimaryButton(
                label: 'Submit for review',
                isLoading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _positiveNumber(String? value, {required String field}) {
    final required = Validators.required(value, field: field);
    if (required != null) return required;
    final n = double.tryParse(value!.trim());
    if (n == null || n <= 0) return '$field must be greater than 0';
    return null;
  }

  String? _positiveInt(String? value, {required String field}) {
    final required = Validators.required(value, field: field);
    if (required != null) return required;
    final n = int.tryParse(value!.trim());
    if (n == null || n <= 0) return '$field must be a whole number above 0';
    return null;
  }

  /// A coordinate is now required so the bakery is discoverable by distance.
  String? _coordValidator(String? value, {required String field}) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return '$field is required';
    if (double.tryParse(t) == null) return 'Invalid number';
    return null;
  }
}

/// Shown once KYC has been submitted: under review, approved, or suspended.
class _StatusView extends StatelessWidget {
  const _StatusView({required this.profile});

  final MyBakerProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final approved = profile.isApproved;

    final (IconData icon, Color color, String title, String body) = approved
        ? (
            Icons.verified_outlined,
            Colors.green,
            'Your bakery is verified',
            'You can publish products and start receiving custom orders.',
          )
        : (
            Icons.hourglass_top_outlined,
            theme.colorScheme.primary,
            'Submitted for review',
            'Thanks! Our team is reviewing your bakery. You can explore your '
                'dashboard in the meantime — publishing unlocks once approved.',
          );

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 72, color: color),
              const SizedBox(height: 20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),
              PrimaryButton(
                label: 'Go to dashboard',
                onPressed: () => context.goNamed(AppRoutes.bakerHomeName),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A dashed "add document" tile shown at the end of the KYC document strip.
class _AddDocButton extends StatelessWidget {
  const _AddDocButton({required this.busy, required this.onTap});

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
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outline),
        ),
        child: Center(
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_a_photo_outlined,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 4),
                    Text('Add', style: theme.textTheme.labelSmall),
                  ],
                ),
        ),
      ),
    );
  }
}

/// A picked KYC document thumbnail with a remove affordance.
class _DocThumb extends StatelessWidget {
  const _DocThumb({required this.bytes, required this.onRemove});

  final Uint8List bytes;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(bytes, width: 96, height: 96, fit: BoxFit.cover),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(2),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}
