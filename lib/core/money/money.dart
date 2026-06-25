/// Money lives as integer minor units (cents) everywhere in the app.
/// These helpers are the only input/display boundary (FLUTTER_PLAN.md §2):
/// parsing uses Decimal (never double) so amounts stay exact.
library;

import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

final _displayFormat = NumberFormat('#,##0.00');

/// Parses user input into minor units. Accepts a plain amount ("450",
/// "450.5", "1,250.75") or a simple arithmetic expression ("100+50",
/// "12.5*2", "(10+5)/3"); see [evaluateAmount]. Returns null for empty,
/// non-numeric, zero/negative, or results needing more than two decimals.
int? parseAmountToMinor(String input) {
  final value = evaluateAmount(input);
  if (value == null || value <= Decimal.zero) return null;
  if (value.scale > 2) return null;
  final minor = (value * Decimal.fromInt(100)).toBigInt();
  if (!minor.isValidInt) return null;
  return minor.toInt();
}

/// Evaluates a simple arithmetic expression with exact [Decimal] math,
/// supporting `+ - * /`, parentheses, and decimals — e.g. "100+50" -> 150,
/// "12.5*2" -> 25. A bare number evaluates to itself, so this is a superset
/// of plain amount entry. Commas and spaces are ignored. Returns null if the
/// input isn't a well-formed expression (including division by zero).
Decimal? evaluateAmount(String input) {
  final cleaned = input.replaceAll(',', '').replaceAll(' ', '');
  if (cleaned.isEmpty) return null;
  try {
    return _ExprParser(cleaned).parse();
  } catch (_) {
    return null;
  }
}

/// Recursive-descent parser for [evaluateAmount]. Grammar:
///   expr   := term (('+' | '-') term)*
///   term   := factor (('*' | '/') factor)*
///   factor := number | '(' expr ')' | ('+' | '-') factor
/// Throws on any malformed input; [evaluateAmount] turns that into null.
class _ExprParser {
  _ExprParser(this._s);

  final String _s;
  int _pos = 0;

  Decimal parse() {
    final value = _expr();
    if (_pos != _s.length) throw const FormatException('trailing input');
    return value;
  }

  Decimal _expr() {
    var value = _term();
    while (_pos < _s.length) {
      final c = _s[_pos];
      if (c == '+') {
        _pos++;
        value += _term();
      } else if (c == '-') {
        _pos++;
        value -= _term();
      } else {
        break;
      }
    }
    return value;
  }

  Decimal _term() {
    var value = _factor();
    while (_pos < _s.length) {
      final c = _s[_pos];
      if (c == '*') {
        _pos++;
        value *= _factor();
      } else if (c == '/') {
        _pos++;
        final divisor = _factor();
        if (divisor == Decimal.zero) {
          throw const FormatException('division by zero');
        }
        value = (value / divisor).toDecimal(scaleOnInfinitePrecision: 10);
      } else {
        break;
      }
    }
    return value;
  }

  Decimal _factor() {
    final c = _s[_pos]; // RangeError past the end is caught by evaluateAmount.
    if (c == '(') {
      _pos++;
      final value = _expr();
      if (_pos >= _s.length || _s[_pos] != ')') {
        throw const FormatException('unbalanced parentheses');
      }
      _pos++;
      return value;
    }
    if (c == '+') {
      _pos++;
      return _factor();
    }
    if (c == '-') {
      _pos++;
      return -_factor();
    }
    return _number();
  }

  Decimal _number() {
    final start = _pos;
    while (_pos < _s.length &&
        ((_s[_pos].compareTo('0') >= 0 && _s[_pos].compareTo('9') <= 0) ||
            _s[_pos] == '.')) {
      _pos++;
    }
    final token = _s.substring(start, _pos);
    final value = Decimal.tryParse(token);
    if (value == null) throw FormatException('invalid number: "$token"');
    return value;
  }
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
