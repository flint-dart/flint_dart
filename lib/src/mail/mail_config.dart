import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/logs.dart';
import 'package:flint_dart/mail.dart';
import 'package:flint_dart/src/mail/smtp_factory.dart';

class MailConfig {
  /// Call this once during app bootstrap
  /// or anywhere you need to reconfigure mail.
  static void load() {
    final providerStr = FlintEnv.get('MAIL_PROVIDER', 'custom').toLowerCase();

    final provider = _parseProvider(providerStr);

    final host = FlintEnv.get('MAIL_HOST', 'localhost');
    final port = FlintEnv.getInt('MAIL_PORT', 25);
    final username = FlintEnv.get('MAIL_USERNAME', '');
    final password = FlintEnv.get('MAIL_PASSWORD', '');
    final encryption = FlintEnv.get('MAIL_ENCRYPTION', 'tls').toLowerCase();

    final fromAddress = FlintEnv.get('MAIL_FROM_ADDRESS', 'noreply@localhost');
    final fromName = FlintEnv.get('MAIL_FROM_NAME', 'Flint Dart');

    final useSSL = encryption == 'ssl';
    final useTLS = encryption == 'tls';

    Mail.setup(
      provider: provider,
      host: host,
      port: port,
      username: username,
      password: password,
      fromAddress: fromAddress,
      fromName: fromName,
      useSSL: useSSL,
      useTLS: useTLS,
    );

    Log.info('📧 Mail configured using provider: $providerStr');
  }

  /// Converts env string → enum safely
  static MailProvider _parseProvider(String value) {
    return MailProvider.values.firstWhere(
      (p) => p.name == value,
      orElse: () => MailProvider.custom,
    );
  }
}
