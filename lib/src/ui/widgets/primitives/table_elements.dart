import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Table row (tr) element wrapper.
class TableRow extends FlintElement {
  /// Creates a table row.
  TableRow({
    Object? child,
    List<Object?> children = const [],
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
          'tr',
          props: mergeComponentProps(
            props,
            className: className,
            dartStyle: dartStyle,
            style: style,
          ),
          children: normalizeChildren(child, children),
        );
}

/// Table cell (td/th) element wrapper.
class TableCell extends FlintElement {
  /// Creates a table cell (rendered as td by default, or th if [header] is true).
  TableCell({
    Object? child,
    List<Object?> children = const [],
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
    bool header = false,
  }) : super(
          header ? 'th' : 'td',
          props: mergeComponentProps(
            props,
            className: className,
            dartStyle: dartStyle,
            style: style,
          ),
          children: normalizeChildren(child, children),
        );
}

/// Table (table) element wrapper.
class TableElement extends FlintElement {
  /// Creates a table element.
  TableElement({
    Object? child,
    List<Object?> children = const [],
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
          'table',
          props: mergeComponentProps(
            props,
            className: className,
            dartStyle: dartStyle,
            style: style,
          ),
          children: normalizeChildren(child, children),
        );
}
