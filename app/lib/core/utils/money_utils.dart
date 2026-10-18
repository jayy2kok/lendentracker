import 'package:intl/intl.dart';

/// Currency-aware formatting and minor-unit arithmetic utilities.
/// All persisted amounts are in integer minor units (paise, cents).
abstract final class MoneyUtils {
  /// Format [minorUnits] for display with the given [currencyCode].
  /// INR → ₹1,234.56  USD → $1,234.56
  static String format(int minorUnits, String currencyCode) {
    final major = minorUnits / _subunits(currencyCode);
    final fmt = NumberFormat.currency(
      symbol: _symbol(currencyCode),
      decimalDigits: _decimals(currencyCode),
    );
    return fmt.format(major);
  }

  /// Parse a user-entered major-unit string to minor units.
  /// Returns null if input is not a valid positive amount.
  static int? parseToMinor(String input, String currencyCode) {
    final cleaned = input.trim();
    if (!RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(cleaned)) return null;
    final parsed = double.tryParse(cleaned);
    if (parsed == null || !parsed.isFinite || parsed < 0) return null;
    return (parsed * _subunits(currencyCode)).round();
  }

  /// Number of decimal digits for a currency.
  static int _decimals(String code) => switch (code.toUpperCase()) {
    'INR' || 'JPY' || 'KRW' => 2,
    _ => 2,
  };

  /// Subunits per major unit (paisa, cents).
  static double _subunits(String code) => switch (code.toUpperCase()) {
    'INR' || 'JPY' || 'KRW' => 100,
    _ => 100,
  };

  static String _symbol(String code) => switch (code.toUpperCase()) {
    'INR' => '₹',
    'USD' => '\$',
    'EUR' => '€',
    'GBP' => '£',
    _ => '$code ',
  };

  /// Validate a simple E.164 phone number (regex fallback).
  /// Returns true for plausible E.164 format.
  static bool isValidE164(String phone) {
    return RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phone.trim());
  }
}
