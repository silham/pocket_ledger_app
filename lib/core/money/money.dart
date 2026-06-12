/// Money lives as integer minor units (cents) everywhere in the app.
/// These helpers are the only input/display boundary (FLUTTER_PLAN.md §2):
/// parsing uses Decimal (never double) so amounts stay exact.
library;

import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

final _displayFormat = NumberFormat('#,##0.00');

/// Parses user input like "450", "450.5" or "1,250.75" into minor units.
/// Returns null for empty, non-numeric, zero/negative, or more than
/// two decimal places.
int? parseAmountToMinor(String input) {
  final cleaned = input.trim().replaceAll(',', '');
  if (cleaned.isEmpty) return null;
  final value = Decimal.tryParse(cleaned);
  if (value == null || value <= Decimal.zero) return null;
  if (value.scale > 2) return null;
  final minor = (value * Decimal.fromInt(100)).toBigInt();
  if (!minor.isValidInt) return null;
  return minor.toInt();
}

/// Minor units -> plain editable text: 45050 -> "450.50", 45000 -> "450".
/// Used to prefill the amount field when editing.
String minorToInputString(int minor) {
  final abs = minor.abs();
  final whole = abs ~/ 100;
  final cents = abs % 100;
  final sign = minor < 0 ? '-' : '';
  if (cents == 0) return '$sign$whole';
  return '$sign$whole.${cents.toString().padLeft(2, '0')}';
}

/// Formats minor units for display: 45050 -> "Rs. 450.50".
String formatMinor(int minor, {String symbol = 'Rs.'}) {
  final sign = minor < 0 ? '-' : '';
  return '$sign$symbol ${_displayFormat.format(minor.abs() / 100)}';
}
