// // lib/flint_ui/widgets/stateful_box.dart

// import '../core/core.dart';
// import '../core/state.dart';
// import 'package:universal_html/html.dart' as html;

// /// A stateful container that can manage reactive state
// class FlintStatefulBox extends FlintStatefulWidget {
//   final FlintWidget child;
//   final BoxConstraints? constraints;
//   final EdgeInsets? padding;
//   final EdgeInsets? margin;
//   final String? backgroundColor;
//   final BoxBorder? border;
//   final BorderRadius? borderRadius;
//   final BoxShadow? shadow;
//   final BoxAlignment alignment;
//   final BoxDecoration? decoration;
//   final String id;

//   @override
//   Map<String, dynamic> get state => _state;
//   Map<String, dynamic> _state = {};

//   FlintStatefulBox({
//     required this.child,
//     this.constraints,
//     this.padding,
//     this.margin,
//     this.backgroundColor,
//     this.border,
//     this.borderRadius,
//     this.shadow,
//     this.alignment = BoxAlignment.start,
//     this.decoration,
//     this.id = '',
//     Map<String, dynamic>? initialState,
//   }) {
//     _state = initialState ?? {};
//     initState();
//   }

//   @override
//   void initState() {
//     // Initialize any state-dependent logic here
//   }

//   @override
//   void dispose() {
//     // Clean up any resources
//   }

//   // @override
//   // void setState(() {
//   //   super.setState(() {
//   //     _state.addAll(newState);
//   //   });
//   // })

//   /// Update a specific state value
//   // void updateState(String key, dynamic value) {
//   //   setState({key: value});
//   // }

//   /// Get a state value
//   dynamic getState(String key) => _state[key];

//   @override
//   String toHtml() {
//     final style = _buildBoxStyle();
//     final attributes = _buildHtmlAttributes();
//     final eventAttrs = eventAttributes.isNotEmpty ? ' $eventAttributes' : '';
//     final childHtml = child.toHtml();

//     return '''
// <div$attributes$eventAttrs style="$style">
//   ${_renderChild()}
// </div>
// ''';
//   }

//   @override
//   String toText() {
//     final content = child.toText();
//     if (backgroundColor != null || border != null) {
//       return '┌${'─' * 40}┐\n$content\n└${'─' * 40}┘';
//     }
//     return content;
//   }

//   @override
//   Map<String, dynamic> toJson() => {
//         'type': 'stateful_box',
//         'child': child.toJson(),
//         'id': id,
//         'state': Map<String, dynamic>.from(_state),
//         'constraints': constraints?.toJson(),
//         'padding': padding?.toJson(),
//         'margin': margin?.toJson(),
//         'backgroundColor': backgroundColor,
//         'border': border?.toJson(),
//         'borderRadius': borderRadius?.toJson(),
//         'shadow': shadow?.toJson(),
//         'alignment': alignment.name,
//         'decoration': decoration?.toJson(),
//         'events': {
//           'hasMouseEnter': onMouseEnter != null,
//           'hasMouseLeave': onMouseLeave != null,
//           'hasClick': onClick != null,
//           'hasTap': onTap != null,
//         },
//       };

//   String _buildBoxStyle() {
//     final styles = <String>[];

//     // Layout
//     if (constraints != null) {
//       if (constraints!.maxWidth != double.infinity) {
//         styles.add('max-width: ${constraints!.maxWidth}px;');
//       }
//       if (constraints!.minWidth != null) {
//         styles.add('min-width: ${constraints!.minWidth}px;');
//       }
//     }

//     // Spacing
//     if (padding != null) styles.add('padding: ${padding!.toCss()};');
//     if (margin != null) styles.add('margin: ${margin!.toCss()};');

//     // Background & Border - can be dynamic based on state
//     final bgColor = getState('backgroundColor') ?? backgroundColor;
//     if (bgColor != null) {
//       styles.add('background-color: $bgColor;');
//     }

//     final currentBorder = getState('border') ?? border;
//     if (currentBorder != null) {
//       styles.add('border: ${currentBorder.toCss()};');
//     }

//     if (borderRadius != null) {
//       styles.add('border-radius: ${borderRadius!.toCss()};');
//     }

//     // Shadow
//     if (shadow != null) {
//       styles.add('box-shadow: ${shadow!.toCss()};');
//     }

//     // Alignment
//     styles.add('text-align: ${alignment.toCss()};');

//     // Box model
//     styles.addAll([
//       'box-sizing: border-box;',
//       'display: block;',
//     ]);

//     // Event-related styles
//     if (onClick != null || onTap != null) {
//       styles.add('cursor: pointer;');
//     }

//     if (onMouseEnter != null || onMouseLeave != null) {
//       styles.add('transition: all 0.3s ease;');
//     }

//     return styles.join(' ');
//   }

//   String _buildHtmlAttributes() {
//     final attrs = <String>[];

//     // Add data-flint-id for event targeting
//     if (id.isNotEmpty) {
//       attrs.add(' data-flint-id="stateful-box-$id"');
//     }

//     if (decoration?.semanticLabel != null) {
//       attrs.add(' aria-label="${_escapeHtml(decoration!.semanticLabel!)}"');
//     }

//     // Add role for accessibility if clickable
//     if (onClick != null || onTap != null) {
//       attrs.add(' role="button"');
//       attrs.add(' tabindex="0"');
//     }

//     // Add state data attributes
//     _state.forEach((key, value) {
//       if (value != null) {
//         attrs.add(' data-state-$key="${_escapeHtml(value.toString())}"');
//       }
//     });

//     return attrs.join();
//   }

//   String _renderChild() {
//     // Apply alignment wrapper if needed
//     if (alignment == BoxAlignment.center) {
//       return '''
// <div style="display: flex; justify-content: center; align-items: center;">
//   ${child.toHtml()}
// </div>
// ''';
//     } else if (alignment == BoxAlignment.end) {
//       return '''
// <div style="display: flex; justify-content: flex-end; align-items: center;">
//   ${child.toHtml()}
// </div>
// ''';
//     }

//     return child.toHtml();
//   }

//   String _escapeHtml(String text) {
//     return text
//         .replaceAll('&', '&amp;')
//         .replaceAll('<', '&lt;')
//         .replaceAll('>', '&gt;')
//         .replaceAll('"', '&quot;');
//   }

//   @override
//   FlintWidget buildTemplate() {
//     return FlintStatefulBox(
//       child: child.buildTemplate(),
//       constraints: constraints,
//       padding: padding,
//       margin: margin,
//       backgroundColor: backgroundColor,
//       border: border,
//       borderRadius: borderRadius,
//       shadow: shadow,
//       alignment: alignment,
//       decoration: decoration,
//       id: id,
//       initialState: Map<String, dynamic>.from(_state),
//     );
//   }

//   @override
//   // TODO: implement onClick
//   void Function(html.Event event)? get onClick => throw UnimplementedError();

//   @override
//   // TODO: implement onMouseEnter
//   void Function(html.Event event)? get onMouseEnter =>
//       throw UnimplementedError();

//   @override
//   // TODO: implement onMouseLeave
//   void Function(html.Event event)? get onMouseLeave =>
//       throw UnimplementedError();

//   @override
//   // TODO: implement onTap
//   void Function()? get onTap => throw UnimplementedError();
// }
