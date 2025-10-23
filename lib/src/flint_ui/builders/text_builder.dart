// // lib/flint_ui/builders/text_builder.dart

// import 'package:flint_dart/src/flint_ui/core/style.dart';
// import 'package:flint_dart/src/flint_ui/widgets/text.dart';
// import 'package:flint_dart/src/flint_ui/themes/text_themes.dart';
// import 'package:flint_dart/src/flint_ui/widgets/rich_text.dart';

// class FlintTextBuilder {
//   static FlintText headline(String text, {TextAlign align = TextAlign.center}) {
//     return FlintText(
//       text,
//       style: FlintTextStyles.headlineMedium,
//       align: align,
//     );
//   }

//   static FlintText body(String text, {TextAlign align = TextAlign.left}) {
//     return FlintText(
//       text,
//       style: FlintTextStyles.bodyMedium,
//       align: align,
//     );
//   }

//   static FlintText caption(String text, {TextAlign align = TextAlign.center}) {
//     return FlintText(
//       text,
//       style: FlintTextStyles.caption,
//       align: align,
//     );
//   }

//   static FlintRichText linkText({
//     required String text,
//     required String url,
//     String? displayUrl,
//   }) {
//     return FlintRichText(
//       children: [
//         FlintTextSpan(text),
//         FlintTextSpan(
//           displayUrl ?? url,
//           style: FlintTextStyles.link,
//           onTap: url,
//         ),
//       ],
//     );
//   }
// }
