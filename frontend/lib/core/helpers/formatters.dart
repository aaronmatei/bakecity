import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Formatting helpers for currency, dates and quantities.
class Formatters {
  const Formatters._();

  static final NumberFormat _currency = NumberFormat.currency(
    locale: AppConstants.defaultLocale,
    symbol: 'KES ',
    decimalDigits: 0,
  );

  static final DateFormat _eventDate = DateFormat('EEE, d MMM yyyy');
  static final DateFormat _eventDateTime = DateFormat('EEE, d MMM yyyy • h:mm a');
  static final DateFormat _shortDate = DateFormat('d MMM');
  static final DateFormat _clock = DateFormat('h:mm a');

  /// Formats a minor-unit amount (cents) as KES currency.
  static String currencyFromCents(int cents) =>
      _currency.format(cents / 100);

  /// Formats a major-unit amount as KES currency.
  static String currency(num amount) => _currency.format(amount);

  /// Formats an event date such as a cake delivery day.
  static String eventDate(DateTime date) => _eventDate.format(date.toLocal());

  /// Formats an event date including the time of day.
  static String eventDateTime(DateTime date) =>
      _eventDateTime.format(date.toLocal());

  /// Compact date label, e.g. "4 Jul".
  static String shortDate(DateTime date) => _shortDate.format(date.toLocal());

  /// Clock time, e.g. "9:42 AM" — used for delivery ETAs.
  static String clockTime(DateTime time) => _clock.format(time.toLocal());

  /// Relative, human-friendly description of a past timestamp.
  static String relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return shortDate(time);
  }
}
