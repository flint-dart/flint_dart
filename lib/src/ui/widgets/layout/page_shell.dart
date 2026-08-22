import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';
import 'constrained_box.dart';
import 'safe_area.dart';

/// Full-page layout with optional navigation, header, content, and footer.
class PageShell extends FlintElement {
  /// Creates a centered page shell with configurable spacing and safe area.
  PageShell({
    Object? nav,
    Object? header,
    Object? child,
    List<Object?> children = const [],
    Object? footer,
    Object maxWidth = 1200,
    Object padding = 24,
    Object gap = 32,
    bool safeArea = true,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    DartStyle? contentDartStyle,
  }) : super(
         'div',
         props: mergeComponentProps(
           props,
           className: className,
           dartStyle: DartStyle(
             minHeight: '100vh',
             display: Display.grid,
             gridTemplateColumns: 'minmax(0, 1fr)',
             gap: gap,
             padding: EdgeInsets.all(padding),
           ).merge(dartStyle),
           style: style,
         ),
         children: [
           if (nav != null) toFlintNode(nav),
           _content(
             header: header,
             child: child,
             children: children,
             footer: footer,
             maxWidth: maxWidth,
             safeArea: safeArea,
             contentDartStyle: contentDartStyle,
           ),
         ],
       );

  static FlintNode _content({
    required Object? header,
    required Object? child,
    required List<Object?> children,
    required Object? footer,
    required Object maxWidth,
    required bool safeArea,
    required DartStyle? contentDartStyle,
  }) {
    final content = ConstrainedBox(
      maxWidth: maxWidth,
      center: true,
      dartStyle: const DartStyle(
        display: Display.grid,
        gap: 24,
      ).merge(contentDartStyle),
      children: [
        if (header != null) header,
        FlintElement('main', children: normalizeChildren(child, children)),
        if (footer != null) footer,
      ],
    );

    return safeArea ? SafeArea(minimum: 0, child: content) : content;
  }
}
