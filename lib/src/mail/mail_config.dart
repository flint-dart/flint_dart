import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/mail.dart';

class MailConfig {
  static void load() {
    final provider = FlintEnv.get('MAIL_PROVIDER', 'smtp');
    final host = FlintEnv.get('MAIL_HOST', 'localhost');
    final port = FlintEnv.getInt('MAIL_PORT', 25);
    final username = FlintEnv.get('MAIL_USERNAME', '');
    final password = FlintEnv.get('MAIL_PASSWORD', '');
    final encryption = FlintEnv.get('MAIL_ENCRYPTION', 'tls');
    final fromEmail = FlintEnv.get('MAIL_FROM_ADDRESS', 'tls');
    final fromName = FlintEnv.get("MAIL_FROM_NAME", "Flint dart");
    final useSSL = encryption.toLowerCase() == 'ssl';
    final useTLS = encryption.toLowerCase() == 'tls';

    switch (provider) {
      case 'gmail':
        Mail.setup(
            host: host,
            port: port,
            username: username,
            password: password,
            fromAddress: fromEmail,
            fromName: fromName,
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
            fromAddress: fromEmail,
            fromName: fromName,
            useTLS: useTLS);
        break;
      case 'zoho':
        Mail.setup(
            host: host,
            port: port,
            username: username,
            password: password,
            fromAddress: fromEmail,
            fromName: fromName,
            useSSL: useSSL,
            useTLS: useTLS);
        break;
      case 'mailgun':
        Mail.setup(
            host: host,
            port: port,
            username: username,
            password: password,
            fromAddress: fromEmail,
            fromName: fromName,
            useSSL: useSSL,
            useTLS: useTLS);
        break;
      case 'sendgrid':
        Mail.setup(
            host: host,
            port: port,
            username: username,
            password: password,
            fromAddress: fromEmail,
            fromName: fromName,
            useSSL: useSSL,
            useTLS: useTLS);
        break;
      default:
        Mail.setup(
            host: host,
            port: port,
            username: username,
            password: password,
            fromAddress: fromEmail,
            fromName: fromName,
            useSSL: useSSL,
            useTLS: useTLS);
    }

    print('📧 Mail configured automatically for provider: $provider');
  }
}
