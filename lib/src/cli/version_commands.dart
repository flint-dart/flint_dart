import 'package:flint_dart/src/cli/constants.dart';

import 'commands.dart';

/// 🛈 Shows the current Flint Dart CLI/framework version
class VersionCommand extends FlintCommand {
  VersionCommand()
      : super('version', 'Shows the current Flint Dart CLI version');

  @override
  Future<void> execute(List<String> args) async {
    print('🔥 Flint Dart CLI version: $flintVersion');
  }
}
