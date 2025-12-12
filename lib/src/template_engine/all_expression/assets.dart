import 'package:flint_dart/src/helpers/helper.dart';

import 'baseRun.dart';

class AssetsProcessor implements BaseExpression {
  @override
  String run(String content, [Map<String, dynamic>? context]) {
    final assetsPattern = RegExp(
      r"(\/?)\{{\s*assets\(\s*'([^']*)'\s*\)\s*}}",
      dotAll: true,
    );

    return content.replaceAllMapped(assetsPattern, (match) {
      final assets = match.group(2);
      return url(assets ?? '');
    });
  }
}
