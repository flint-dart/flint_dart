import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Renders an HTML `iframe` element.
class Iframe extends FlintElement {
  /// Creates an `iframe` element with source URL, title, and styling.
  Iframe({
    required String src,
    String? title,
    String? width,
    String? height,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
          'iframe',
          props: mergeComponentProps(
            {
              ...props,
              'src': src,
              if (title != null) 'title': title,
              if (width != null) 'width': width,
              if (height != null) 'height': height,
            },
            className: className,
            dartStyle: dartStyle,
            style: style,
          ),
        );
}
