import 'dart:io';

import 'package:flint_dart/ai.dart';
import 'package:flint_dart/flint_dart.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('flint_ai_env_test_');
  });

  tearDown(() {
    FlintEnv.setEnvFilePath(null);
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('registers chat providers from env credentials', () {
    final envFile = File('${tempDir.path}/.env')..writeAsStringSync('''
OPENAI_API_KEY=openai-key
GEMINI_BEARER_TOKEN=gemini-token
ANTHROPIC_API_KEY=anthropic-key
''');
    FlintEnv.setEnvFilePath(envFile.path);

    final ai = FlintAi();
    final registered = ai.useChatProvidersFromEnv();

    expect(registered, containsAll(['openai', 'gemini', 'anthropic']));
    expect(ai.providers.chatProvider('openai'), isNotNull);
    expect(ai.providers.chatProvider('gemini'), isNotNull);
    expect(ai.providers.chatProvider('anthropic'), isNotNull);
  });

  test('applies production tool policy from env allow-lists', () async {
    final envFile = File('${tempDir.path}/.env')..writeAsStringSync('''
AI_ALLOWED_TOOLS=reports.export
AI_ALLOWED_CAPABILITIES=support:write,billing:refund
AI_ALLOWED_ROLES=ADMIN,OWNER
''');
    FlintEnv.setEnvFilePath(envFile.path);

    final ai = FlintAi();
    ai.useProductionToolPolicyFromEnv();

    final allowedByTool = await ai.toolPolicy.canExecute(
      const AiToolInvocation(
        name: 'reports.export',
        runId: 'run-1',
        userId: 'user-1',
        arguments: {},
      ),
    );
    final allowedByRole = await ai.toolPolicy.canExecute(
      const AiToolInvocation(
        name: 'billing.delete',
        runId: 'run-1',
        userId: 'user-1',
        arguments: {},
        userRoles: {'ADMIN'},
      ),
    );
    final deniedAnonymous = await ai.toolPolicy.canExecute(
      const AiToolInvocation(
        name: 'reports.export',
        runId: 'run-1',
        arguments: {},
      ),
    );

    expect(allowedByTool, isTrue);
    expect(allowedByRole, isTrue);
    expect(deniedAnonymous, isFalse);
  });
}
