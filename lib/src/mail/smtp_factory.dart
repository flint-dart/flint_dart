import 'package:mailer/smtp_server.dart';

class SmtpFactory {
  static SmtpServer create({
    required MailProvider provider,
    required String host,
    required int port,
    required String username,
    required String password,
    String encryption = 'tls',
    bool allowInsecure = true,
    bool ignoreBadCertificate = true,
  }) {
    switch (provider) {
      case MailProvider.gmail:
        return SmtpServer(
          'smtp.gmail.com',
          port: 587,
          username: username,
          password: password,
          ssl: false,
          allowInsecure: allowInsecure,
          ignoreBadCertificate: ignoreBadCertificate,
        );

      case MailProvider.outlook:
        return SmtpServer(
          'smtp.office365.com',
          port: 587,
          username: username,
          password: password,
          ssl: false,
          allowInsecure: allowInsecure,
          ignoreBadCertificate: ignoreBadCertificate,
        );

      case MailProvider.yahoo:
        return SmtpServer(
          'smtp.mail.yahoo.com',
          port: 465,
          username: username,
          password: password,
          ssl: true,
          allowInsecure: allowInsecure,
          ignoreBadCertificate: ignoreBadCertificate,
        );

      case MailProvider.custom:
        return SmtpServer(
          host,
          port: port,
          username: username,
          password: password,
          ssl: encryption == 'ssl',
          allowInsecure: allowInsecure,
          ignoreBadCertificate: ignoreBadCertificate,
        );
    }
  }
}

enum MailProvider {
  gmail,
  outlook,
  yahoo,
  custom,
}
