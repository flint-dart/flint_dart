import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Box that preserves a CSS aspect ratio.
class AspectRatioBox extends FlintElement {
  /// Creates an aspect-ratio box from [ratio].
  AspectRatioBox({
    required Object ratio,
    Object? child,
    List<Object?> children = const [],
    Object? width,
    Object? overflow,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
         'div',
         props: mergeComponentProps(
           props,
           className: className,
           dartStyle: DartStyle(
             width: width ?? SizeValue.full,
             aspectRatio: ratio,
             overflow: overflow,
           ).merge(dartStyle),
           style: style,
         ),
         children: normalizeChildren(child, children),
       );

  /// Creates a square aspect-ratio box.
  AspectRatioBox.square({
    Object? child,
    List<Object?> children = const [],
    Object? width,
    Object? overflow,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : this(
         ratio: '1 / 1',
         child: child,
         children: children,
         width: width,
         overflow: overflow,
         className: className,
         props: props,
         style: style,
         dartStyle: dartStyle,
       );

  /// Creates a 16:9 aspect-ratio box.
  AspectRatioBox.video({
    Object? child,
    List<Object?> children = const [],
    Object? width,
    Object? overflow,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : this(
         ratio: '16 / 9',
         child: child,
         children: children,
         width: width,
         overflow: overflow,
         className: className,
         props: props,
         style: style,
         dartStyle: dartStyle,
       );
}
