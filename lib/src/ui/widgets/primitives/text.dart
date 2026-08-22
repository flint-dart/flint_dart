import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Text node and semantic text element helpers.
class Text extends FlintText {
  /// Creates a plain text node from [value].
  Text(Object? value) : super(value?.toString() ?? '');

  /// Creates an `h1` text element.
  static FlintElement h1(
    Object? value, {
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) => _element('h1', value, className, props, style, dartStyle);

  /// Creates an `h2` text element.
  static FlintElement h2(
    Object? value, {
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) => _element('h2', value, className, props, style, dartStyle);

  /// Creates an `h3` text element.
  static FlintElement h3(
    Object? value, {
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) => _element('h3', value, className, props, style, dartStyle);

  /// Creates a paragraph text element.
  static FlintElement p(
    Object? value, {
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) => _element('p', value, className, props, style, dartStyle);

  /// Creates an inline `span` text element.
  static FlintElement span(
    Object? value, {
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) => _element('span', value, className, props, style, dartStyle);

  /// Creates a `strong` text element.
  static FlintElement strong(
    Object? value, {
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) => _element('strong', value, className, props, style, dartStyle);

  /// Creates a `small` text element.
  static FlintElement small(
    Object? value, {
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) => _element('small', value, className, props, style, dartStyle);
}

FlintElement _element(
  String tag,
  Object? value,
  String? className,
  Map<String, Object?> props,
  Map<String, Object?> style,
  DartStyle? dartStyle,
) {
  return FlintElement(
    tag,
    props: mergeComponentProps(
      props,
      className: className,
      dartStyle: dartStyle,
      style: style,
    ),
    children: normalizeChildren(value, const []),
  );
}
