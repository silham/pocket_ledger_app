import 'package:flutter/material.dart';

/// Parses "#RRGGBB" (as stored on categories/accounts) into a [Color].
/// Falls back to [fallback] for null/malformed values.
Color colorFromHex(String? hex, {Color fallback = const Color(0xFF6366F1)}) {
  if (hex == null) return fallback;
  final cleaned = hex.replaceFirst('#', '');
  if (cleaned.length != 6) return fallback;
  final value = int.tryParse(cleaned, radix: 16);
  if (value == null) return fallback;
  return Color(0xFF000000 | value);
}
