// // lib/flint_ui/widgets/counter.dart

// import 'package:universal_html/html.dart' as html;

// import '../core/core.dart';

// /// A simple counter widget demonstrating state management
// class FlintCounter extends FlintStatefulWidget {
//   final String id;
//   final int initialCount;
//   final TextStyle? textStyle;
//   final ButtonStyle? buttonStyle;

//   @override
//   Map<String, dynamic> get state => _state;
//   Map<String, dynamic> _state = {};

//   FlintCounter({
//     this.id = '',
//     this.initialCount = 0,
//     this.textStyle,
//     this.buttonStyle,
//   }) {
//     _state = {'count': initialCount};
//     initState();
//   }

//   @override
//   void initState() {
//     // Could set up timers, listeners, etc.
//   }

//   @override
//   void dispose() {
//     // Clean up resources
//   }

//   void setStates(Map<String, dynamic> newState) {
//     super.setState(() {
//       _state.addAll(newState);
//     });
//   }

//   void increment() {
//     setStates({'count': _state['count'] + 1});
//   }

//   void decrement() {
//     setStates({'count': _state['count'] - 1});
//   }

//   void reset() {
//     setStates({'count': initialCount});
//   }

//   @override
//   String toHtml() {
//     final count = _state['count'] ?? initialCount;
//     final eventAttrs = eventAttributes.isNotEmpty ? ' $eventAttributes' : '';
//     final dataId = id.isNotEmpty ? ' data-flint-id="counter-$id"' : '';

//     return '''
// <div$dataId$eventAttrs style="text-align: center; padding: 20px;">
//   <div style="font-size: ${textStyle?.fontSize ?? 24}px; 
//               color: ${textStyle?.color ?? '#333'}; 
//               margin-bottom: 16px;">
//     Count: $count
//   </div>
//   <div style="display: flex; gap: 8px; justify-content: center;">
//     <button onclick="flintEvents.handleCounterDecrement('$id')" 
//             style="${_buildButtonStyle()}">
//       -
//     </button>
//     <button onclick="flintEvents.handleCounterReset('$id')" 
//             style="${_buildButtonStyle()}">
//       Reset
//     </button>
//     <button onclick="flintEvents.handleCounterIncrement('$id')" 
//             style="${_buildButtonStyle()}">
//       +
//     </button>
//   </div>
// </div>
// ''';
//   }

//   String _buildButtonStyle() {
//     final style = buttonStyle ?? ButtonStyle.primary();
//     return '''
//     display: inline-block;
//     padding: 8px 16px;
//     background-color: ${style.backgroundColor};
//     color: ${style.textStyle.color ?? '#fff'};
//     border: ${style.border?.toCss() ?? 'none'};
//     border-radius: 4px;
//     cursor: pointer;
//     font-size: 16px;
//     transition: all 0.2s ease;
//   ''';
//   }

//   @override
//   String toText() {
//     final count = _state['count'] ?? initialCount;
//     return 'Counter: $count (Use buttons to interact in web version)';
//   }

//   @override
//   Map<String, dynamic> toJson() => {
//         'type': 'counter',
//         'id': id,
//         'state': Map<String, dynamic>.from(_state),
//         'initialCount': initialCount,
//         'textStyle': textStyle?.toJson(),
//         'buttonStyle': buttonStyle?.toJson(),
//       };

//   @override
//   FlintWidget buildTemplate() => FlintCounter(
//         id: id,
//         initialCount: initialCount,
//         textStyle: textStyle,
//         buttonStyle: buttonStyle,
//       );

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
