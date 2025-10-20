import 'dart:math';
import 'package:uuid/uuid.dart';

/// Utility class for generating and manipulating strings in Flint Dart
class Str {
  static final _uuid = const Uuid();
  static final _chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  static final _letters =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  static final _numbers = '0123456789';
  static final _random = Random.secure();

  /// Generate a random numeric OTP (e.g. 6 digits)
  static String otp([int length = 6]) {
    return List.generate(
        length, (_) => _numbers[_random.nextInt(_numbers.length)]).join();
  }

  /// Generate a UUID (v4)
  static String uuid() {
    return _uuid.v4();
  }

  /// Generate a random alphanumeric string
  static String random([int length = 16]) {
    return List.generate(length, (_) => _chars[_random.nextInt(_chars.length)])
        .join();
  }

  /// Generate a random alphabet-only string
  static String randomLetters([int length = 10]) {
    return List.generate(
        length, (_) => _letters[_random.nextInt(_letters.length)]).join();
  }

  /// Generate a random numeric string
  static String randomNumbers([int length = 6]) {
    return List.generate(
        length, (_) => _numbers[_random.nextInt(_numbers.length)]).join();
  }

  /// Create a URL-friendly slug from any string
  static String slugify(String text) {
    return text
        .toLowerCase()
        .replaceAll(
            RegExp(r'[^a-z0-9]+'), '-') // Replace non-alphanumerics with '-'
        .replaceAll(RegExp(r'(^-|-$)'), ''); // Trim leading/trailing '-'
  }

  /// Generate a secure random token (base64-like)
  static String token([int length = 32]) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-';
    return List.generate(length, (_) => chars[_random.nextInt(chars.length)])
        .join();
  }

  /// Capitalize the first letter of a string
  static String capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  /// Convert a string to snake_case
  static String snake(String text) {
    return text
        .replaceAllMapped(
            RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
        .toLowerCase();
  }

  /// Convert a string to camelCase
  static String camel(String text) {
    final parts = text.split(RegExp(r'[_\s-]+'));
    return parts.first.toLowerCase() +
        parts.skip(1).map((w) => capitalize(w.toLowerCase())).join();
  }
}
