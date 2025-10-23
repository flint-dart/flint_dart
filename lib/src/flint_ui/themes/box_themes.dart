// // lib/flint_ui/themes/box_themes.dart

// import 'package:flint_dart/src/flint_ui/core/box_style.dart';
// import 'package:flint_dart/src/flint_ui/core/edge_insets.dart';
// import 'package:flint_dart/src/flint_ui/core/framework.dart';
// import 'package:flint_dart/src/flint_ui/widgets/flint_box.dart';

// class FlintBoxStyles {
//   /// Card styles
//   static FlintBox card({required List<FlintWidget> children}) {
//     return FlintBox(
//       children: children,
//       padding: EdgeInsets.all(16),
//       backgroundColor: '#ffffff',
//       border: BoxBorder(width: 1, color: '#e0e0e0'),
//       borderRadius: BorderRadius.circular(8),
//       shadow: BoxShadow(
//         offsetY: 2,
//         blurRadius: 8,
//         color: 'rgba(0, 0, 0, 0.1)',
//       ),
//     );
//   }

//   /// Alert styles
//   static FlintBox alert({
//     required List<FlintWidget> children,
//     String backgroundColor = '#fff3cd',
//     String borderColor = '#ffeaa7',
//   }) {
//     return FlintBox(
//       children: children,
//       padding: EdgeInsets.all(12),
//       backgroundColor: backgroundColor,
//       border: BoxBorder(width: 1, color: borderColor),
//       borderRadius: BorderRadius.circular(4),
//     );
//   }

//   /// Container with max width for email compatibility
//   static FlintBox emailContainer({required List<FlintWidget> children}) {
//     return FlintBox(
//       children: children,
//       constraints: BoxConstraints(maxWidth: 600),
//       padding: EdgeInsets.all(20),
//       backgroundColor: '#ffffff',
//     );
//   }

//   /// Section divider
//   static FlintBox divider({String color = '#e0e0e0', double height = 1}) {
//     return FlintBox(
//       children: [],
//       constraints: BoxConstraints.tightFor(height: height),
//       backgroundColor: color,
//       margin: EdgeInsets.symmetric(vertical: 16),
//     );
//   }

//   /// Hero section with gradient
//   static FlintBox hero({required List<FlintWidget> children}) {
//     return FlintBox(
//       children: children,
//       padding: EdgeInsets.all(40),
//       decoration: BoxDecoration(
//         gradient: Gradient.linear(
//           stops: [
//             ColorStop('#667eea', 0),
//             ColorStop('#764ba2', 1),
//           ],
//         ),
//       ),
//       alignment: BoxAlignment.center,
//     );
//   }
// }
