import 'component.dart';
import 'node.dart';
import 'style.dart';

/// Merges component props, classes, inline styles, and scoped Dart styles.
Map<String, Object?> mergeComponentProps(
  Map<String, Object?> props, {
  String? className,
  Map<String, Object?> defaultStyle = const {},
  Map<String, Object?> variantStyle = const {},
  DartStyle? dartStyle,
  Map<String, Object?> style = const {},
}) {
  final existingClass = props['className']?.toString();
  final existingStyle = props['style'];
  final mergedStyle = mergeStyles(
    defaultStyle,
    variantStyle,
    dartStyle?.toMap() ?? const {},
    style,
    switch (existingStyle) {
      Map<String, Object?> map => map,
      String css => {'_cssText': css},
      _ => const <String, Object?>{},
    },
  );

  final next = {...props}..remove('style');
  final scopedClass = dartStyle?.hasScopedStyles == true
      ? _scopedClassName(dartStyle!)
      : null;
  final classes = joinClassNames([existingClass, className, scopedClass]);

  return {
    ...next,
    if (classes.isNotEmpty) 'className': classes,
    if (scopedClass != null)
      '_flintStyleCss': _scopedCss(scopedClass, dartStyle!),
    if (mergedStyle.isNotEmpty)
      'style': existingStyle is String
          ? [
              styleToCss(
                mergeStyles(
                  defaultStyle,
                  variantStyle,
                  dartStyle?.toMap() ?? const {},
                  style,
                ),
              ),
              existingStyle,
            ].where((value) => value.trim().isNotEmpty).join('; ')
          : mergedStyle,
  };
}

/// Combines style maps from left to right, ignoring null values.
Map<String, Object?> mergeStyles(
  Map<String, Object?> first,
  Map<String, Object?> second, [
  Map<String, Object?> third = const {},
  Map<String, Object?> fourth = const {},
  Map<String, Object?> fifth = const {},
]) {
  return {
    for (final style in [first, second, third, fourth, fifth])
      for (final entry in style.entries)
        if (entry.value != null && entry.key != '_cssText')
          entry.key: entry.value,
  };
}

/// Normalizes a single child and additional children into Flint nodes.
List<FlintNode> normalizeChildren(Object? child, List<Object?> children) {
  final values = [if (child != null) child, ...children];

  return values.map(toFlintNode).toList(growable: false);
}

/// Converts common Dart values into a renderable Flint node.
FlintNode toFlintNode(Object? value) {
  if (value is FlintNode) return value;
  if (value is FlintComponent) return FlintComponentNode(value);
  if (value is Iterable<Object?>) {
    return FlintFragment(value.map(toFlintNode).toList(growable: false));
  }
  return FlintText(value?.toString() ?? '');
}

/// Joins non-empty CSS class names with spaces.
String joinClassNames(Iterable<String?> values) {
  return values
      .where((value) => value != null && value.trim().isNotEmpty)
      .map((value) => value!.trim())
      .join(' ');
}

/// Converts a style map into a CSS declaration string.
String styleToCss(Map<String, Object?> style) {
  return style.entries
      .where((entry) => entry.value != null && entry.key != '_cssText')
      .map((entry) => '${entry.key}: ${entry.value}')
      .join('; ');
}

String _scopedClassName(DartStyle style) {
  return 'flint-s-${_stableHash(_scopedCssBody(style)).toRadixString(36)}';
}

String _scopedCss(String className, DartStyle style) {
  final chunks = <String>[];

  for (final entry in style.stateStyles.entries) {
    final body = _styleToCssImportant(entry.value.toMap());
    if (body.isEmpty) continue;
    chunks.add('.$className${entry.key} { $body; }');
  }

  for (final entry in style.themeStyles.entries) {
    final body = _styleToCssImportant(entry.value.toMap());
    if (body.isEmpty) continue;
    final theme = entry.key.value;
    chunks.add(
      '[data-theme="$theme"] .$className, .$className[data-theme="$theme"] { $body; }',
    );
  }

  for (final entry in style.breakpointStyles.entries) {
    final body = _styleToCssImportant(entry.value.toMap());
    if (body.isEmpty) continue;
    chunks.add(
      '@media (min-width: ${entry.key.minWidth}px) { .$className { $body; } }',
    );
  }
  return chunks.join('\n');
}

String _scopedCssBody(DartStyle style) {
  return [
    ...style.stateStyles.entries.map(
      (entry) => '${entry.key}:${styleToCss(entry.value.toMap())}',
    ),
    ...style.themeStyles.entries.map(
      (entry) => '${entry.key.value}:${styleToCss(entry.value.toMap())}',
    ),
    ...style.breakpointStyles.entries.map(
      (entry) => '${entry.key.name}:${styleToCss(entry.value.toMap())}',
    ),
  ].join('|');
}

String _styleToCssImportant(Map<String, Object?> style) {
  return style.entries
      .where((entry) => entry.value != null && entry.key != '_cssText')
      .map((entry) => '${entry.key}: ${entry.value} !important')
      .join('; ');
}

int _stableHash(String value) {
  var hash = 0x811c9dc5;

  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xffffffff;
  }
  return hash;
}
