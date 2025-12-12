// import 'dart:convert';

// import 'abs_processor.dart';

// class TranslateProcessor implements BaseExpression {
//   @override
//   String parse(String content, [Map<String, dynamic>? context]) {
//     final translatePattern = RegExp(
//       r"\{\@\s*trans\(\s*'([^']+)'\s*"
//       r"(?:,\s*({[^}]+}))?\s*"
//       r"(?:,\s*([^)]+?))?\s*"
//       r"\)\s*\}}",
//       dotAll: true,
//     );
//     return content.replaceAllMapped(translatePattern, (match) {
//       final key = match.group(1) ?? '';
//       Map<String, dynamic> args = {};
//       final rawArgs = match.group(2);
//       if (rawArgs != null) {
//         try {
//           args = jsonDecode(rawArgs) as Map<String, dynamic>;
//         } catch (_) {}
//       }
//       final stripQuotes = RegExp(r"""^['"]|['"]$""");
//       String? locale;
//       final rawLocale = match.group(3);
//       if (rawLocale != null) {
//         locale = rawLocale.trim().replaceAll(stripQuotes, '');
//       }
//       return trans(key, args: args, locale: locale);
//     });
//   }
// }
