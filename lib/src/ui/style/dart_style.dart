part of '../style.dart';

/// Typed CSS style object for Flint UI components.
///
/// Use this when you want Dart-friendly values that compile to inline CSS and
/// scoped responsive or state styles.
class DartStyle {
  /// CSS `padding` using typed edge inset values.
  final EdgeInsets? padding;

  /// CSS `margin` using typed edge inset values.
  final EdgeInsets? margin;

  /// CSS `width` value.
  final Object? width;

  /// CSS `height` value.
  final Object? height;

  /// CSS `min-width` value.
  final Object? minWidth;

  /// CSS `max-width` value.
  final Object? maxWidth;

  /// CSS `min-height` value.
  final Object? minHeight;

  /// CSS `max-height` value.
  final Object? maxHeight;

  /// CSS `display` value.
  final Display? display;

  /// CSS `gap` value.
  final Object? gap;

  /// CSS `align-items` value.
  final AlignItems? alignItems;

  /// CSS `justify-items` value.
  final Object? justifyItems;

  /// CSS `justify-content` value.
  final JustifyContent? justifyContent;

  /// CSS `flex` shorthand value.
  final Object? flex;

  /// CSS `flex-direction` value.
  final FlexDirection? flexDirection;

  /// CSS `flex-wrap` value.
  final Object? flexWrap;

  /// CSS `flex-grow` value.
  final Object? flexGrow;

  /// CSS `flex-shrink` value.
  final Object? flexShrink;

  /// CSS `flex-basis` value.
  final Object? flexBasis;

  /// CSS `grid-template-columns` value.
  final Object? gridTemplateColumns;

  /// CSS `position` value.
  final Position? position;

  /// CSS `top` offset value.
  final Object? top;

  /// CSS `right` offset value.
  final Object? right;

  /// CSS `bottom` offset value.
  final Object? bottom;

  /// CSS `left` offset value.
  final Object? left;

  /// CSS `z-index` value.
  final int? zIndex;

  /// CSS `overflow` value.
  final Object? overflow;

  /// CSS `overflow-x` value.
  final Object? overflowX;

  /// CSS `overflow-y` value.
  final Object? overflowY;

  /// CSS `box-sizing` value.
  final Object? boxSizing;

  /// CSS `scroll-behavior` value.
  final Object? scrollBehavior;

  /// CSS scrollbar visibility helper.
  final Object? scrollbarDisplay;

  /// CSS `aspect-ratio` value.
  final Object? aspectRatio;

  /// CSS `object-fit` value for replaced elements such as images.
  final Object? objectFit;

  /// CSS `transform` value.
  final Object? transform;

  /// CSS `backdrop-filter` value.
  final Object? backdropFilter;

  /// CSS `mask-image` value.
  final Object? maskImage;

  /// CSS `font-family` value.
  final Object? fontFamily;

  /// CSS `font-size` value.
  final Object? fontSize;

  /// CSS `font-weight` value.
  final Object? fontWeight;

  /// CSS `line-height` value.
  final Object? lineHeight;

  /// CSS `letter-spacing` value.
  final Object? letterSpacing;

  /// CSS `color` value.
  final Object? color;

  /// CSS `text-align` value.
  final TextAlign? textAlign;

  /// CSS `text-transform` value.
  final Object? textTransform;

  /// CSS `text-decoration` value.
  final Object? textDecoration;

  /// CSS `text-overflow` value.
  final Object? textOverflow;

  /// CSS `white-space` value.
  final Object? whiteSpace;

  /// CSS `word-break` value.
  final Object? wordBreak;

  /// CSS `overflow-wrap` value.
  final Object? overflowWrap;

  /// CSS `cursor` value.
  final Object? cursor;

  /// CSS `resize` value.
  final Object? resize;

  /// CSS `background` value used when [gradient] is not set.
  final Object? background;

  /// CSS `border-radius` value.
  final Object? radius;

  /// CSS `border` shorthand value.
  final Border? border;

  /// CSS `border-top` value.
  final Border? borderTop;

  /// CSS `border-right` value.
  final Border? borderRight;

  /// CSS `border-bottom` value.
  final Border? borderBottom;

  /// CSS `border-left` value.
  final Border? borderLeft;

  /// CSS `border-collapse` value.
  final Object? borderCollapse;

  /// CSS `box-shadow` value.
  final Object? shadow;

  /// CSS `opacity` value.
  final double? opacity;

  /// CSS background gradient value.
  ///
  /// When provided, this takes precedence over [background].
  final Object? gradient;

  /// CSS `background-clip` value.
  final Object? backgroundClip;

  /// CSS vendor-prefixed `-webkit-background-clip` value.
  final Object? webkitBackgroundClip;

  /// CSS `transition` value.
  final Object? transition;

  /// CSS `animation` value.
  final Object? animation;

  /// CSS `will-change` value.
  final Object? willChange;

  /// Scoped style applied for the CSS `:hover` state.
  final DartStyle? hover;

  /// Scoped style applied for the CSS `:focus` state.
  final DartStyle? focus;

  /// Scoped style applied for the CSS `:focus-visible` state.
  final DartStyle? focusVisible;

  /// Scoped style applied for the CSS `:active` state.
  final DartStyle? active;

  /// Scoped style applied for disabled controls and `aria-disabled`.
  final DartStyle? disabled;

  /// Scoped style applied for the CSS `:checked` state.
  final DartStyle? checked;

  /// Scoped style applied when `aria-selected="true"`.
  final DartStyle? selected;

  /// Scoped style applied when `aria-expanded="true"`.
  final DartStyle? expanded;

  /// Scoped style applied when `aria-invalid="true"`.
  final DartStyle? invalid;

  /// Scoped style applied when the nearest Flint theme is light.
  final DartStyle? light;

  /// Scoped style applied when the nearest Flint theme is dark.
  final DartStyle? dark;

  /// Responsive style applied from the small breakpoint.
  final DartStyle? sm;

  /// Responsive style applied from the medium breakpoint.
  final DartStyle? md;

  /// Responsive style applied from the large breakpoint.
  final DartStyle? lg;

  /// Responsive style applied from the extra-large breakpoint.
  final DartStyle? xl;

  /// Creates a typed style object.
  ///
  /// Numeric size-like values compile to pixels unless a typed value such as
  /// [SizeValue] is provided.
  const DartStyle({
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.minWidth,
    this.maxWidth,
    this.minHeight,
    this.maxHeight,
    this.display,
    this.gap,
    this.alignItems,
    this.justifyItems,
    this.justifyContent,
    this.flex,
    this.flexDirection,
    this.flexWrap,
    this.flexGrow,
    this.flexShrink,
    this.flexBasis,
    this.gridTemplateColumns,
    this.position,
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.zIndex,
    this.overflow,
    this.overflowX,
    this.overflowY,
    this.boxSizing,
    this.scrollBehavior,
    this.scrollbarDisplay,
    this.aspectRatio,
    this.objectFit,
    this.transform,
    this.backdropFilter,
    this.maskImage,
    this.fontFamily,
    this.fontSize,
    this.fontWeight,
    this.lineHeight,
    this.letterSpacing,
    this.color,
    this.textAlign,
    this.textTransform,
    this.textDecoration,
    this.textOverflow,
    this.whiteSpace,
    this.wordBreak,
    this.overflowWrap,
    this.cursor,
    this.resize,
    this.background,
    this.radius,
    this.border,
    this.borderTop,
    this.borderRight,
    this.borderBottom,
    this.borderLeft,
    this.borderCollapse,
    this.shadow,
    this.opacity,
    this.gradient,
    this.backgroundClip,
    this.webkitBackgroundClip,
    this.transition,
    this.animation,
    this.willChange,
    this.hover,
    this.focus,
    this.focusVisible,
    this.active,
    this.disabled,
    this.checked,
    this.selected,
    this.expanded,
    this.invalid,
    this.light,
    this.dark,
    this.sm,
    this.md,
    this.lg,
    this.xl,
  });

  /// Converts base style values to a CSS property map.
  ///
  /// State and breakpoint styles are intentionally excluded from this map and
  /// are exposed through [stateStyles] and [breakpointStyles].
  Map<String, Object?> toMap() {
    return _withoutNulls({
      'padding': padding?.toCss(),
      'margin': margin?.toCss(),
      'width': cssValue(width),
      'height': cssValue(height),
      'min-width': cssValue(minWidth),
      'max-width': cssValue(maxWidth),
      'min-height': cssValue(minHeight),
      'max-height': cssValue(maxHeight),
      'display': display?.css,
      'gap': cssValue(gap),
      'align-items': alignItems?.css,
      'justify-items': cssValue(justifyItems, unitlessNumber: true),
      'justify-content': justifyContent?.css,
      'flex': cssValue(flex, unitlessNumber: true),
      'flex-direction': flexDirection?.css,
      'flex-wrap': cssValue(flexWrap, unitlessNumber: true),
      'flex-grow': cssValue(flexGrow, unitlessNumber: true),
      'flex-shrink': cssValue(flexShrink, unitlessNumber: true),
      'flex-basis': cssValue(flexBasis),
      'grid-template-columns': cssValue(
        gridTemplateColumns,
        unitlessNumber: true,
      ),
      'position': position?.css,
      'top': cssValue(top),
      'right': cssValue(right),
      'bottom': cssValue(bottom),
      'left': cssValue(left),
      'z-index': zIndex,
      'overflow': cssValue(overflow, unitlessNumber: true),
      'overflow-x': cssValue(overflowX, unitlessNumber: true),
      'overflow-y': cssValue(overflowY, unitlessNumber: true),
      'box-sizing': cssValue(boxSizing, unitlessNumber: true),
      'scroll-behavior': cssValue(scrollBehavior, unitlessNumber: true),
      'scrollbar-display': cssValue(scrollbarDisplay, unitlessNumber: true),
      'scrollbar-width': _scrollbarWidth(scrollbarDisplay),
      '-ms-overflow-style': _msOverflowStyle(scrollbarDisplay),
      'aspect-ratio': cssValue(aspectRatio, unitlessNumber: true),
      'object-fit': cssValue(objectFit, unitlessNumber: true),
      'transform': cssValue(transform, unitlessNumber: true),
      'backdrop-filter': cssValue(backdropFilter, unitlessNumber: true),
      'mask-image': cssValue(maskImage, unitlessNumber: true),
      'font-family': cssValue(fontFamily, unitlessNumber: true),
      'font-size': cssValue(fontSize),
      'font-weight': cssValue(fontWeight, unitlessNumber: true),
      'line-height': cssValue(lineHeight, unitlessNumber: true),
      'letter-spacing': cssValue(letterSpacing),
      'color': cssValue(color),
      'text-align': textAlign?.css,
      'text-transform': cssValue(textTransform, unitlessNumber: true),
      'text-decoration': cssValue(textDecoration, unitlessNumber: true),
      'text-overflow': cssValue(textOverflow, unitlessNumber: true),
      'white-space': cssValue(whiteSpace, unitlessNumber: true),
      'word-break': cssValue(wordBreak, unitlessNumber: true),
      'overflow-wrap': cssValue(overflowWrap, unitlessNumber: true),
      'cursor': cssValue(cursor, unitlessNumber: true),
      'resize': cssValue(resize, unitlessNumber: true),
      'background': cssValue(gradient ?? background),
      'background-clip': cssValue(backgroundClip, unitlessNumber: true),
      '-webkit-background-clip': cssValue(
        webkitBackgroundClip,
        unitlessNumber: true,
      ),
      'border-radius': cssValue(radius),
      'border': border?.toCss(),
      'border-top': borderTop?.toCss(),
      'border-right': borderRight?.toCss(),
      'border-bottom': borderBottom?.toCss(),
      'border-left': borderLeft?.toCss(),
      'border-collapse': cssValue(borderCollapse, unitlessNumber: true),
      'box-shadow':
          shadow is Shadow ? (shadow as Shadow).toCss() : cssValue(shadow),
      'opacity': opacity,
      'transition': cssValue(transition, unitlessNumber: true),
      'animation': cssValue(animation, unitlessNumber: true),
      'will-change': cssValue(willChange, unitlessNumber: true),
    });
  }

  /// Whether this style contains responsive breakpoint overrides.
  bool get hasBreakpoints =>
      sm != null || md != null || lg != null || xl != null;

  /// Whether this style contains scoped state overrides.
  bool get hasStateStyles =>
      hover != null ||
      focus != null ||
      focusVisible != null ||
      active != null ||
      disabled != null ||
      checked != null ||
      selected != null ||
      expanded != null ||
      invalid != null ||
      light != null ||
      dark != null;

  /// Whether this style contains any responsive or state overrides.
  bool get hasScopedStyles => hasBreakpoints || hasStateStyles;

  /// Responsive styles keyed by their breakpoint.
  Map<Breakpoint, DartStyle> get breakpointStyles => {
        if (sm != null) Breakpoint.sm: sm!,
        if (md != null) Breakpoint.md: md!,
        if (lg != null) Breakpoint.lg: lg!,
        if (xl != null) Breakpoint.xl: xl!,
      };

  /// Scoped state styles keyed by CSS selector suffix.
  Map<String, DartStyle> get stateStyles => {
        if (hover != null) ':hover': hover!,
        if (focus != null) ':focus': focus!,
        if (focusVisible != null) ':focus-visible': focusVisible!,
        if (active != null) ':active': active!,
        if (disabled != null) ':disabled': disabled!,
        if (disabled != null) '[aria-disabled="true"]': disabled!,
        if (checked != null) ':checked': checked!,
        if (selected != null) '[aria-selected="true"]': selected!,
        if (expanded != null) '[aria-expanded="true"]': expanded!,
        if (invalid != null) '[aria-invalid="true"]': invalid!,
      };

  /// Theme-scoped styles keyed by Flint theme name.
  Map<FlintThemeMode, DartStyle> get themeStyles => {
        if (light != null) FlintThemeMode.light: light!,
        if (dark != null) FlintThemeMode.dark: dark!,
      };

  /// Returns a new style with non-null values from [override] applied.
  DartStyle merge(DartStyle? override) {
    if (override == null) return this;

    return DartStyle(
      padding: override.padding ?? padding,
      margin: override.margin ?? margin,
      width: override.width ?? width,
      height: override.height ?? height,
      minWidth: override.minWidth ?? minWidth,
      maxWidth: override.maxWidth ?? maxWidth,
      minHeight: override.minHeight ?? minHeight,
      maxHeight: override.maxHeight ?? maxHeight,
      display: override.display ?? display,
      gap: override.gap ?? gap,
      alignItems: override.alignItems ?? alignItems,
      justifyItems: override.justifyItems ?? justifyItems,
      justifyContent: override.justifyContent ?? justifyContent,
      flex: override.flex ?? flex,
      flexDirection: override.flexDirection ?? flexDirection,
      flexWrap: override.flexWrap ?? flexWrap,
      flexGrow: override.flexGrow ?? flexGrow,
      flexShrink: override.flexShrink ?? flexShrink,
      flexBasis: override.flexBasis ?? flexBasis,
      gridTemplateColumns: override.gridTemplateColumns ?? gridTemplateColumns,
      position: override.position ?? position,
      top: override.top ?? top,
      right: override.right ?? right,
      bottom: override.bottom ?? bottom,
      left: override.left ?? left,
      zIndex: override.zIndex ?? zIndex,
      overflow: override.overflow ?? overflow,
      overflowX: override.overflowX ?? overflowX,
      overflowY: override.overflowY ?? overflowY,
      boxSizing: override.boxSizing ?? boxSizing,
      scrollBehavior: override.scrollBehavior ?? scrollBehavior,
      scrollbarDisplay: override.scrollbarDisplay ?? scrollbarDisplay,
      aspectRatio: override.aspectRatio ?? aspectRatio,
      objectFit: override.objectFit ?? objectFit,
      transform: override.transform ?? transform,
      backdropFilter: override.backdropFilter ?? backdropFilter,
      maskImage: override.maskImage ?? maskImage,
      fontFamily: override.fontFamily ?? fontFamily,
      fontSize: override.fontSize ?? fontSize,
      fontWeight: override.fontWeight ?? fontWeight,
      lineHeight: override.lineHeight ?? lineHeight,
      letterSpacing: override.letterSpacing ?? letterSpacing,
      color: override.color ?? color,
      textAlign: override.textAlign ?? textAlign,
      textTransform: override.textTransform ?? textTransform,
      textDecoration: override.textDecoration ?? textDecoration,
      textOverflow: override.textOverflow ?? textOverflow,
      whiteSpace: override.whiteSpace ?? whiteSpace,
      wordBreak: override.wordBreak ?? wordBreak,
      overflowWrap: override.overflowWrap ?? overflowWrap,
      cursor: override.cursor ?? cursor,
      resize: override.resize ?? resize,
      background: override.background ?? background,
      radius: override.radius ?? radius,
      border: override.border ?? border,
      borderTop: override.borderTop ?? borderTop,
      borderRight: override.borderRight ?? borderRight,
      borderBottom: override.borderBottom ?? borderBottom,
      borderLeft: override.borderLeft ?? borderLeft,
      borderCollapse: override.borderCollapse ?? borderCollapse,
      shadow: override.shadow ?? shadow,
      opacity: override.opacity ?? opacity,
      gradient: override.gradient ?? gradient,
      backgroundClip: override.backgroundClip ?? backgroundClip,
      webkitBackgroundClip:
          override.webkitBackgroundClip ?? webkitBackgroundClip,
      transition: override.transition ?? transition,
      animation: override.animation ?? animation,
      willChange: override.willChange ?? willChange,
      hover: override.hover ?? hover,
      focus: override.focus ?? focus,
      focusVisible: override.focusVisible ?? focusVisible,
      active: override.active ?? active,
      disabled: override.disabled ?? disabled,
      checked: override.checked ?? checked,
      selected: override.selected ?? selected,
      expanded: override.expanded ?? expanded,
      invalid: override.invalid ?? invalid,
      light: override.light ?? light,
      dark: override.dark ?? dark,
      sm: override.sm ?? sm,
      md: override.md ?? md,
      lg: override.lg ?? lg,
      xl: override.xl ?? xl,
    );
  }
}

String? _scrollbarWidth(Object? value) {
  if (value == null) return null;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'none') return 'none';
  if (normalized == 'auto') return 'auto';
  return null;
}

String? _msOverflowStyle(Object? value) {
  if (value == null) return null;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized == 'none') return 'none';
  if (normalized == 'auto') return 'auto';
  return null;
}
