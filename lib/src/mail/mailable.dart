// lib/mail/mailable.dart

import 'package:flint_dart/mail.dart' as mailer;

abstract class Mailable {
  /// The subject line of the email
  String get subject;

  /// The view path for the email template (relative to lib/mail/)
  String get view;

  /// The data map available inside the template
  Map<String, dynamic> get data;

  /// Optional list of email recipients
  List<String> get to;

  /// Optional list of CC recipients
  List<String> get cc => [];

  /// Optional list of BCC recipients
  List<String> get bcc => [];

  /// Optional list of attachments
  List<dynamic> get attachments => [];

  /// Optional from address
  String? get from => null;

  /// Optional reply-to address
  String? get replyTo => null;

  /// Send the email immediately
  Future<void> send() async {
    validate();
    final htmlContent = await _renderTemplate();

    final mail = mailer.Mail().toMany(to).subject(subject).html(htmlContent);

    // Add optional fields
    if (cc.isNotEmpty) mail.ccMany(cc);
    if (bcc.isNotEmpty) mail.bccMany(bcc);
    if (from != null) {
      // Note: You might need to extend your Mail class to support custom from
    }

    await mail.sendMail();
  }

  /// Queue the email for background sending
  Future<void> queue() async {
    validate();
    final htmlContent = await _renderTemplate();

    final mail = mailer.Mail().toMany(to).subject(subject).html(htmlContent);

    if (cc.isNotEmpty) mail.ccMany(cc);
    if (bcc.isNotEmpty) mail.bccMany(bcc);

    await mail.queue();
  }

  /// Validation method to ensure required fields are present
  void validate() {
    if (to.isEmpty) {
      throw StateError('Mailable must have at least one recipient in "to"');
    }
    if (subject.isEmpty) {
      throw StateError('Mailable must have a non-empty subject');
    }
    if (view.isEmpty) {
      throw StateError('Mailable must have a view path');
    }
  }

  /// Template rendering - to be implemented by the framework
  Future<String> _renderTemplate() async {
    // This would be implemented by your template engine
    // For now, return a simple HTML structure
    return '''
<html>
<body>
  <h1>$subject</h1>
  <p>Template: $view</p>
  <pre>${data.toString()}</pre>
</body>
</html>
''';
  }
}
