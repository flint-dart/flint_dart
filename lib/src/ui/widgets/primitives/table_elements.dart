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

/// Table head (thead) element wrapper.
class TableHead extends FlintElement {
  /// Creates a table head.
  TableHead({
    Object? child,
    List<Object?> children = const [],
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
          'thead',
          props: mergeComponentProps(
            props,
            className: className,
            dartStyle: dartStyle,
            style: style,
          ),
          children: normalizeChildren(child, children),
        );
}

/// Table body (tbody) element wrapper.
class TableBody extends FlintElement {
  /// Creates a table body.
  TableBody({
    Object? child,
    List<Object?> children = const [],
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
          'tbody',
          props: mergeComponentProps(
            props,
            className: className,
            dartStyle: dartStyle,
            style: style,
          ),
          children: normalizeChildren(child, children),
        );
}

/// Table foot (tfoot) element wrapper.
class TableFoot extends FlintElement {
  /// Creates a table foot.
  TableFoot({
    Object? child,
    List<Object?> children = const [],
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
          'tfoot',
          props: mergeComponentProps(
            props,
            className: className,
            dartStyle: dartStyle,
            style: style,
          ),
          children: normalizeChildren(child, children),
        );
}

/// Table header cell (th) element wrapper.
class TableHeaderCell extends FlintElement {
  /// Creates a table header cell.
  TableHeaderCell({
    Object? child,
    List<Object?> children = const [],
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
          'th',
          props: mergeComponentProps(
            props,
            className: className,
            dartStyle: dartStyle,
            style: style,
          ),
          children: normalizeChildren(child, children),
        );
}
