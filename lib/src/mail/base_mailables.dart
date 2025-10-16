// lib/mail/base_mailables.dart

import 'package:flint_dart/mail.dart';

/// Base class for all transactional emails
abstract class TransactionalMailable extends Mailable {
  final String recipientName;
  final String recipientEmail;

  TransactionalMailable({
    required this.recipientName,
    required this.recipientEmail,
  });

  @override
  List<String> get to => [recipientEmail];

  @override
  MailPriority get priority => MailPriority.high;
}

/// Base class for notification emails
abstract class NotificationMailable extends Mailable {
  final String recipientName;
  final String recipientEmail;

  NotificationMailable({
    required this.recipientName,
    required this.recipientEmail,
  });

  @override
  List<String> get to => [recipientEmail];

  @override
  MailPriority get priority => MailPriority.normal;
}

/// Base class for marketing emails
abstract class MarketingMailable extends Mailable {
  final List<String> recipients;

  MarketingMailable({
    required this.recipients,
  });

  @override
  List<String> get to => recipients;

  @override
  MailPriority get priority => MailPriority.low;

  @override
  String? get from => 'marketing@example.com';

  @override
  String? get fromName => 'Marketing Team';
}
