// lib/mail/mailable.dart

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
