import 'dart:io';

import 'package:flint_dart/flint_dart.dart';
import 'package:test/test.dart';

void main() {
  test('MailConfig.load reads .env without throwing', () async {
    final tempDir = await Directory.systemTemp.createTemp('flint_mail_test_');
    final envFile = File('${tempDir.path}/.env');

    try {
      envFile.writeAsStringSync('''
MAIL_PROVIDER=custom
MAIL_HOST=localhost
MAIL_PORT=2525
MAIL_USERNAME=user
MAIL_PASSWORD=pass
MAIL_FROM_ADDRESS=noreply@example.com
MAIL_FROM_NAME=Test App
MAIL_ENCRYPTION=tls
''');

      FlintEnv.setEnvFilePath(envFile.path);
      expect(() => MailConfig.load(), returnsNormally);
    } finally {
      FlintEnv.setEnvFilePath(null);
      await tempDir.delete(recursive: true);
    }
  });
}
