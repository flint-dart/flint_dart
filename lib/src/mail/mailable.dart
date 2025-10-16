// lib/mail/mailable.dart

import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/flint_ui.dart';

abstract class Mailable {
  /// The email subject line
  String get subject;

  /// List of primary recipients
  List<String> get to;

  /// List of CC recipients
  List<String> get cc => [];

  /// List of BCC recipients
  List<String> get bcc => [];

  /// Sender email address (optional - uses default if null)
  String? get from => null;

  /// Sender name (optional)
  String? get fromName => null;

  /// Reply-to address (optional)
  String? get replyTo => null;

  /// Email priority (optional)
  MailPriority get priority => MailPriority.normal;

  /// List of attachments (optional)
  List<MailAttachment> get attachments => [];

  /// Build the email content using Flint UI widgets
  FlintWidget build();

  /// Send the email immediately
  Future<void> send() async {
    try {
      validate();

      final content = build();
      final html = content.toHtml();
      final text = content.toText();

      final mail = Mail().toMany(to).subject(subject).html(html).text(text);

      // Add optional fields
      if (cc.isNotEmpty) mail.ccMany(cc);
      if (bcc.isNotEmpty) mail.bccMany(bcc);
      if (from != null) {
        // Note: You might need to extend Mail class for custom from
      }
      if (replyTo != null) {
        // Note: You might need to extend Mail class for reply-to
      }

      // Add attachments
      // for (final attachment in attachments) {
      //   // Add attachment logic here
      // }

      await mail.sendMail();
      print('✅ Email sent to: ${to.join(', ')}');
    } catch (e) {
      print('❌ Failed to send email: $e');
      rethrow;
    }
  }

  /// Queue the email for background sending
  Future<void> queue() async {
    try {
      validate();

      final content = build();
      final html = content.toHtml();
      final text = content.toText();

      final mail = Mail().toMany(to).subject(subject).html(html).text(text);

      if (cc.isNotEmpty) mail.ccMany(cc);
      if (bcc.isNotEmpty) mail.bccMany(bcc);

      await mail.queue();
      print('📬 Email queued for: ${to.join(', ')}');
    } catch (e) {
      print('❌ Failed to queue email: $e');
      rethrow;
    }
  }

  /// Validate that required fields are present
  void validate() {
    if (to.isEmpty) {
      throw MailValidationError('At least one recipient is required in "to"');
    }
    if (subject.isEmpty) {
      throw MailValidationError('Subject cannot be empty');
    }
  }

  /// Preview the email in browser
  Future<void> preview() async {
    final content = build();
    FlintPreview.generatePreviewHtml(content, title: subject);
  }

  /// Get HTML content for testing or other purposes
  String toHtml() {
    return build().toHtml();
  }

  /// Get plain text content
  String toText() {
    return build().toText();
  }

  /// Get JSON representation
  Map<String, dynamic> toJson() {
    return build().toJson();
  }

  // /// Create a copy with overridden properties
  // Mailable copyWith({
  //   String? subject,
  //   List<String>? to,
  //   List<String>? cc,
  //   List<String>? bcc,
  //   String? from,
  //   String? fromName,
  //   String? replyTo,
  // });
}

/// Email priority levels
enum MailPriority {
  high('High'),
  normal('Normal'),
  low('Low');

  final String value;
  const MailPriority(this.value);
}

/// Email attachment
class MailAttachment {
  final String filePath;
  final String? fileName;
  final String? contentType;

  const MailAttachment({
    required this.filePath,
    this.fileName,
    this.contentType,
  });
}

/// Mail validation error
class MailValidationError implements Exception {
  final String message;

  const MailValidationError(this.message);

  @override
  String toString() => 'MailValidationError: $message';
}
