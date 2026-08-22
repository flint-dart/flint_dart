import '../../component_props.dart';
import '../../node.dart';
import '../../style.dart';

/// Unified Flex container widget supporting base and responsive layout directions.
class Flex extends FlintElement {
  /// Creates a flex container with optional direction, styles, and children.
  Flex({
    Object? child,
    List<Object?> children = const [],
    FlexDirection direction = FlexDirection.row,
    AlignItems? alignItems,
    JustifyContent? justifyContent,
    Object? gap,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) : super(
          'div',
          props: mergeComponentProps(
            props,
            className: className,
            defaultStyle: const {'display': 'flex'},
            dartStyle: DartStyle(
              display: Display.flex,
              flexDirection: dartStyle?.flexDirection ?? direction,
              alignItems: dartStyle?.alignItems ?? alignItems,
              justifyContent: dartStyle?.justifyContent ?? justifyContent,
              gap: dartStyle?.gap ?? gap,
              padding: dartStyle?.padding,
              margin: dartStyle?.margin,
              width: dartStyle?.width,
              height: dartStyle?.height,
              minWidth: dartStyle?.minWidth,
              maxWidth: dartStyle?.maxWidth,
              minHeight: dartStyle?.minHeight,
              maxHeight: dartStyle?.maxHeight,
              background: dartStyle?.background,
              color: dartStyle?.color,
              fontSize: dartStyle?.fontSize,
              fontWeight: dartStyle?.fontWeight,
              radius: dartStyle?.radius,
              border: dartStyle?.border,
              shadow: dartStyle?.shadow,
              position: dartStyle?.position,
              top: dartStyle?.top,
              right: dartStyle?.right,
              bottom: dartStyle?.bottom,
              left: dartStyle?.left,
              zIndex: dartStyle?.zIndex,
              overflow: dartStyle?.overflow,
              textAlign: dartStyle?.textAlign,
              cursor: dartStyle?.cursor,
              opacity: dartStyle?.opacity,
              transform: dartStyle?.transform,
              transition: dartStyle?.transition,
              backdropFilter: dartStyle?.backdropFilter,
              sm: dartStyle?.sm,
              md: dartStyle?.md,
              lg: dartStyle?.lg,
              xl: dartStyle?.xl,
            ),
            style: style,
          ),
          children: normalizeChildren(child, children),
        );

  /// Named factory constructor for horizontal Flex (Row).
  factory Flex.row({
    Object? child,
    List<Object?> children = const [],
    AlignItems? alignItems,
    JustifyContent? justifyContent,
    Object? gap,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) {
    return Flex(
      child: child,
      children: children,
      direction: FlexDirection.row,
      alignItems: alignItems,
      justifyContent: justifyContent,
      gap: gap,
      className: className,
      props: props,
      style: style,
      dartStyle: dartStyle,
    );
  }

  /// Named factory constructor for vertical Flex (Column).
  factory Flex.column({
    Object? child,
    List<Object?> children = const [],
    AlignItems? alignItems,
    JustifyContent? justifyContent,
    Object? gap,
    String? className,
    Map<String, Object?> props = const {},
    Map<String, Object?> style = const {},
    DartStyle? dartStyle,
  }) {
    return Flex(
      child: child,
      children: children,
      direction: FlexDirection.column,
      alignItems: alignItems,
      justifyContent: justifyContent,
      gap: gap,
      className: className,
      props: props,
      style: style,
      dartStyle: dartStyle,
    );
  }
}
