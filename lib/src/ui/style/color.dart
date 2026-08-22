part of '../style.dart';

/// CSS color value used by typed Flint UI styles.
class Color {
  /// CSS color string.
  final String value;

  /// Creates a color from a raw CSS color [value].
  const Color(this.value);

  /// Creates a color from a hex string.
  const Color.hex(String value) : value = value;

  /// Creates an `rgb(...)` color.
  const Color.rgb(int red, int green, int blue)
    : value = 'rgb($red, $green, $blue)';

  /// Creates an `rgba(...)` color.
  const Color.rgba(int red, int green, int blue, double alpha)
    : value = 'rgba($red, $green, $blue, $alpha)';

  /// Returns the CSS color string.
  @override
  String toString() => value;
}

/// Built-in color tokens for Flint UI examples and components.
class Colors {
  /// Prevents creating a color token container.
  const Colors._();

  static const white = Color('#ffffff');
  static const black = Color('#000000');
  static const transparent = Color('transparent');

  static const slate50 = Color('#f8fafc');
  static const slate100 = Color('#f1f5f9');
  static const slate200 = Color('#e2e8f0');
  static const slate300 = Color('#cbd5e1');
  static const slate400 = Color('#94a3b8');
  static const slate500 = Color('#64748b');
  static const slate600 = Color('#475569');
  static const slate700 = Color('#334155');
  static const slate800 = Color('#1e293b');
  static const slate900 = Color('#0f172a');

  static const blue50 = Color('#eff6ff');
  static const blue100 = Color('#dbeafe');
  static const blue200 = Color('#bfdbfe');
  static const blue300 = Color('#93c5fd');
  static const blue400 = Color('#60a5fa');
  static const blue500 = Color('#3b82f6');
  static const blue600 = Color('#2563eb');
  static const blue700 = Color('#1d4ed8');
  static const blue800 = Color('#1e40af');
  static const blue900 = Color('#1e3a8a');

  static const sky50 = Color('#f0f9ff');
  static const sky100 = Color('#e0f2fe');
  static const sky200 = Color('#bae6fd');
  static const sky300 = Color('#7dd3fc');
  static const sky400 = Color('#38bdf8');
  static const sky500 = Color('#0ea5e9');
  static const sky600 = Color('#0284c7');
  static const sky700 = Color('#0369a1');
  static const sky800 = Color('#075985');
  static const sky900 = Color('#0c4a6e');

  static const cyan50 = Color('#ecfeff');
  static const cyan700 = Color('#0e7490');

  static const rose50 = Color('#fff1f2');
  static const rose200 = Color('#fecdd3');
  static const rose700 = Color('#be123c');
}
