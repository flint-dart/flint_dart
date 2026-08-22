import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Container that pads content away from browser safe-area insets.
class SafeArea extends FlintElement {
  /// Creates a safe-area wrapper with optional side controls.
  SafeArea({
    Object? child,
    List<Object?> children = const [],
    bool top = true,
    bool right = true,
    bool bottom = true,
    bool left = true,
    Object minimum = 0,
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
             padding: EdgeInsets.only(
               top: top ? _safeInset('top', minimum) : minimum,
               right: right ? _safeInset('right', minimum) : minimum,
               bottom: bottom ? _safeInset('bottom', minimum) : minimum,
               left: left ? _safeInset('left', minimum) : minimum,
             ),
           ).merge(dartStyle),
           style: style,
         ),
         children: normalizeChildren(child, children),
       );

  static String _safeInset(String side, Object minimum) {
    return 'max(env(safe-area-inset-$side), ${cssValue(minimum)})';
  }
}
