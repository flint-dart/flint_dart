//   {{ switch <variable> }}
//     {{ case <value(s)> }}<content>{{ endcase }}
//     {{ default }}<content>{{ enddefault }}   (optional)
//   {{ endswitch }}
import 'package:flint_dart/src/template_engine/all_expression/base_run.dart';

class SwitchCasesProcessor implements BaseExpression {
  /// Parse `{{ switch <variable> }}` blocks in [content] and replace them with
  /// values from [context].
  //
  /// The replacement is done by expanding the matching case content if the
  /// condition is true. If no case matches, the default content is expanded if
  /// it is provided.
  //
  /// The following example:
  ///
  @override
  String run(String content, [Map<String, dynamic>? context]) {
    context ??= {};

    final switchPattern = RegExp(
      r'\{{\s*switch\s+(.*?)\s*}}(.*?)\{{\s*endswitch\s*}}',
      dotAll: true,
    );

    return content.replaceAllMapped(switchPattern, (match) {
      final switchVariable = match.group(1)?.trim() ?? '';
      final switchContent = match.group(2) ?? '';

      final switchValue = context![switchVariable];

      final casePattern = RegExp(
        r'\{{\s*case\s+(.*?)\s*}}(.*?)\{{\s*endcase\s*}}',
        dotAll: true,
      );

      final defaultPattern = RegExp(
        r'\{{\s*default\s*}}(.*?)\{{\s*enddefault\s*}}',
        dotAll: true,
      );

      for (final caseMatch in casePattern.allMatches(switchContent)) {
        final caseValueRaw = caseMatch.group(1)?.trim() ?? '';
        final caseContent = caseMatch.group(2) ?? '';

        final caseValues = caseValueRaw.split(',').map((val) => val.trim());

        for (final value in caseValues) {
          final parsedCaseValue = num.tryParse(value) ?? value;
          final parsedSwitchValue = (switchValue != null)
              ? num.tryParse(switchValue.toString()) ?? switchValue
              : null;

          if (parsedSwitchValue == parsedCaseValue) {
            return caseContent;
          }
        }
      }

      final defaultMatch = defaultPattern.firstMatch(switchContent);
      if (defaultMatch != null) {
        return defaultMatch.group(1)!;
      }

      return '';
    });
  }
}
