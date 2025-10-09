import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/src/mail/mail.dart'; // hypothetical Flint env helper

class MailConfig {
  static void load() {
    final provider = FlintEnv.get('MAIL_PROVIDER', 'smtp');
    final host = FlintEnv.get('MAIL_HOST', 'localhost');
    final port = FlintEnv.getInt('MAIL_PORT', 25);
    final username = FlintEnv.get('MAIL_USERNAME', '');
    final password = FlintEnv.get('MAIL_PASSWORD', '');
    final encryption = FlintEnv.get('MAIL_ENCRYPTION', 'tls');

    final useSSL = encryption.toLowerCase() == 'ssl';
    final useTLS = encryption.toLowerCase() == 'tls';

    switch (provider) {
      case 'gmail':
        Mail.setup(
            host: host,
            port: port,
            username: username,
            password: password,
            useSSL: useSSL,
            useTLS: useTLS);
        break;
      case 'outlook':
        Mail.setup(
            host: host,
            port: port,
            username: username,
            password: password,
            useSSL: useSSL,
            useTLS: useTLS);
        break;
      case 'zoho':
        Mail.setup(
            host: host,
            port: port,
            username: username,
            password: password,
            useSSL: useSSL,
            useTLS: useTLS);
        break;
      case 'mailgun':
        Mail.setup(
            host: host,
            port: port,
            username: username,
            password: password,
            useSSL: useSSL,
            useTLS: useTLS);
        break;
      case 'sendgrid':
        Mail.setup(
            host: host,
            port: port,
            username: username,
            password: password,
            useSSL: useSSL,
            useTLS: useTLS);
        break;
      default:
        Mail.setup(
            host: host,
            port: port,
            username: username,
            password: password,
            useSSL: useSSL,
            useTLS: useTLS);
    }

    print('📧 Mail configured automatically for provider: $provider');
  }
}
