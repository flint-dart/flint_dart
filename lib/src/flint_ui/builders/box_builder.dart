// // lib/flint_ui/builders/box_builder.dart

// import 'package:flint_dart/src/flint_ui/core/box_style.dart';
// import 'package:flint_dart/src/flint_ui/core/button_style.dart';
// import 'package:flint_dart/src/flint_ui/core/edge_insets.dart';
// import 'package:flint_dart/src/flint_ui/core/style.dart';
// import 'package:flint_dart/src/flint_ui/themes/box_themes.dart';
// import 'package:flint_dart/src/flint_ui/themes/text_themes.dart';
// import 'package:flint_dart/src/flint_ui/widgets/flint_box.dart';
// import 'package:flint_dart/src/flint_ui/widgets/flint_button.dart';
// import 'package:flint_dart/src/flint_ui/widgets/rich_text.dart';
// import 'package:flint_dart/src/flint_ui/widgets/text.dart';

// class FlintBoxBuilder {
//   /// Create a card with title and content
//   static FlintBox cardWithTitle({
//     required String title,
//     required String content,
//     TextStyle? titleStyle,
//     TextStyle? contentStyle,
//   }) {
//     return FlintBoxStyles.card(
//       children: [
//         FlintText(title, style: titleStyle ?? FlintTextStyles.headlineSmall),
//         FlintBox(
//           children: [
//             FlintText(content,
//                 style: contentStyle ?? FlintTextStyles.bodyMedium)
//           ],
//           margin: EdgeInsets.only(top: 8),
//         ),
//       ],
//     );
//   }

//   /// Create a notification banner
//   static FlintBox notification({
//     required String message,
//     NotificationType type = NotificationType.info,
//     String? actionText,
//     String? actionUrl,
//   }) {
//     final colors = _getNotificationColors(type);

//     return FlintBox(
//       children: [
//         FlintRichText(
//           children: [
//             FlintTextSpan(_getNotificationIcon(type),
//                 style: TextStyle(fontSize: 16)),
//             FlintTextSpan(' $message'),
//             if (actionText != null && actionUrl != null) ...[
//               FlintTextSpan(' '),
//               FlintTextSpan(
//                 actionText,
//                 style: FlintTextStyles.link.copyWith(color: colors.textColor),
//                 onTap: actionUrl,
//               ),
//             ],
//           ],
//         ),
//       ],
//       padding: EdgeInsets.all(12),
//       backgroundColor: colors.backgroundColor,
//       border: BoxBorder(width: 1, color: colors.borderColor),
//       borderRadius: BorderRadius.circular(4),
//     );
//   }

//   /// Create a pricing card
//   static FlintBox pricingCard({
//     required String title,
//     required String price,
//     required String period,
//     required List<String> features,
//     required String buttonText,
//     required String buttonUrl,
//     bool featured = false,
//   }) {
//     return FlintBox(
//       children: [
//         if (featured)
//           FlintBox(
//             children: [
//               FlintText('Most Popular',
//                   style: FlintTextStyles.caption.copyWith(color: '#ffffff')),
//             ],
//             padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
//             backgroundColor: '#007cba',
//             alignment: BoxAlignment.center,
//             margin: EdgeInsets.only(bottom: 16),
//           ),
//         FlintText(title,
//             style: FlintTextStyles.headlineSmall, align: TextAlign.center),
//         FlintBox(
//           children: [
//             FlintText(price,
//                 style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
//             FlintText('/$period', style: FlintTextStyles.bodySmall),
//           ],
//           alignment: BoxAlignment.center,
//           margin: EdgeInsets.symmetric(vertical: 16),
//         ),
//         FlintBox(
//           children: features
//               .map((feature) =>
//                   FlintText('✓ $feature', style: FlintTextStyles.bodyMedium))
//               .toList(),
//           margin: EdgeInsets.only(bottom: 24),
//         ),
//         FlintButton(
//           text: buttonText,
//           url: buttonUrl,
//           style: featured ? ButtonStyle.primary() : ButtonStyle.secondary(),
//         ),
//       ],
//       padding: EdgeInsets.all(24),
//       backgroundColor: '#ffffff',
//       border: BoxBorder(
//           width: featured ? 2 : 1, color: featured ? '#007cba' : '#e0e0e0'),
//       borderRadius: BorderRadius.circular(8),
//       shadow: featured
//           ? BoxShadow(offsetY: 4, blurRadius: 12)
//           : BoxShadow(offsetY: 2, blurRadius: 8),
//       alignment: BoxAlignment.center,
//     );
//   }

//   static _NotificationColors _getNotificationColors(NotificationType type) {
//     switch (type) {
//       case NotificationType.success:
//         return _NotificationColors('#d4edda', '#c3e6cb', '#155724');
//       case NotificationType.error:
//         return _NotificationColors('#f8d7da', '#f5c6cb', '#721c24');
//       case NotificationType.warning:
//         return _NotificationColors('#fff3cd', '#ffeaa7', '#856404');
//       case NotificationType.info:
//         return _NotificationColors('#d1ecf1', '#bee5eb', '#0c5460');
//     }
//   }

//   static String _getNotificationIcon(NotificationType type) {
//     switch (type) {
//       case NotificationType.success:
//         return '✅';
//       case NotificationType.error:
//         return '❌';
//       case NotificationType.warning:
//         return '⚠️';
//       case NotificationType.info:
//         return 'ℹ️';
//     }
//   }
// }

// class _NotificationColors {
//   final String backgroundColor;
//   final String borderColor;
//   final String textColor;

//   _NotificationColors(this.backgroundColor, this.borderColor, this.textColor);
// }

// enum NotificationType {
//   success,
//   error,
//   warning,
//   info,
// }
