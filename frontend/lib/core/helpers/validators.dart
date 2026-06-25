/// Reusable form field validators returning a null on success or an error
/// message string on failure (matching Flutter's `FormFieldValidator`).
class Validators {
  const Validators._();

  static final RegExp _emailRegExp = RegExp(
    r'^[\w.+-]+@([\w-]+\.)+[\w-]{2,}$',
  );

  // Kenyan-style phone numbers: +2547XXXXXXXX, 07XXXXXXXX, 01XXXXXXXX.
  static final RegExp _phoneRegExp = RegExp(
    r'^(?:\+?254|0)[17]\d{8}$',
  );

  /// Validates that a value is present and non-blank.
  static String? required(String? value, {String field = 'This field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$field is required.';
    }
    return null;
  }

  /// Validates an email address.
  static String? email(String? value) {
    final base = required(value, field: 'Email');
    if (base != null) return base;
    if (!_emailRegExp.hasMatch(value!.trim())) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  /// Validates a phone number (Kenyan formats).
  static String? phone(String? value) {
    final base = required(value, field: 'Phone number');
    if (base != null) return base;
    final normalized = value!.replaceAll(RegExp(r'\s'), '');
    if (!_phoneRegExp.hasMatch(normalized)) {
      return 'Enter a valid phone number.';
    }
    return null;
  }

  /// Validates a password against a minimum length.
  static String? password(String? value, {int minLength = 8}) {
    final base = required(value, field: 'Password');
    if (base != null) return base;
    if (value!.length < minLength) {
      return 'Password must be at least $minLength characters.';
    }
    return null;
  }

  /// Combines multiple validators, returning the first failure.
  static String? Function(String?) compose(
    List<String? Function(String?)> validators,
  ) {
    return (value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) return result;
      }
      return null;
    };
  }
}
