import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flint_dart/logs.dart';
import 'package:flint_dart/src/env_parser.dart';
import 'package:flint_dart/src/mail/smtp_factory.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class Mail {
  // ---- Static SMTP config ----
  static SmtpServer? _server;
  static String? _fromAddress;
  static String? _fromName;
  static String? _defaultReplyTo;
  static bool _autoConfigAttempted = false;

  final List<String> _to = [];
  final List<String> _cc = [];
  final List<String> _bcc = [];
  String? _replyTo;
  String? _subject;
  String? _html;
  String? _text;

  Mail();

  // ---- Setup once ----
  static void setup({
    required MailProvider provider,
    required String host,
    required int port,
    required String username,
    required String password,
    required String fromAddress,
    String fromName = 'Flint Dart',
    String? replyTo,
    bool useSSL = false,
    bool useTLS = true,
  }) {
    _server = SmtpFactory.create(
      provider: provider,
      host: host,
      port: port,
      username: username,
      password: password,
      encryption: useSSL ? 'ssl' : 'tls',
    );

    _fromAddress = fromAddress;
    _fromName = fromName;
    _defaultReplyTo = replyTo;
    _autoConfigAttempted = true;
    Log.debug('Mail server configured for $_fromName <$_fromAddress>@$host');
  }

  static void _ensureConfigured({bool forceReload = false}) {
    if (!forceReload && _server != null) return;
    if (!forceReload && _autoConfigAttempted) return;

    _autoConfigAttempted = true;

    final providerStr = FlintEnv.get('MAIL_PROVIDER', 'custom').toLowerCase();
    final provider = MailProvider.values.firstWhere(
      (p) => p.name == providerStr,
      orElse: () => MailProvider.custom,
    );

    final host = FlintEnv.get('MAIL_HOST', 'localhost');
    final port = FlintEnv.getInt('MAIL_PORT', 25);
    final username = FlintEnv.get('MAIL_USERNAME', '');
    final password = FlintEnv.get('MAIL_PASSWORD', '');
    final encryption = FlintEnv.get('MAIL_ENCRYPTION', 'tls').toLowerCase();
    final fromAddress = FlintEnv.get('MAIL_FROM_ADDRESS', 'noreply@localhost');
    final fromName = FlintEnv.get('MAIL_FROM_NAME', 'Flint Dart');
    final replyTo = FlintEnv.get('MAIL_REPLY_TO', '');

    setup(
      provider: provider,
      host: host,
      port: port,
      username: username,
      password: password,
      fromAddress: fromAddress,
      fromName: fromName,
      replyTo: replyTo.isNotEmpty ? replyTo : null,
      useSSL: encryption == 'ssl',
      useTLS: encryption == 'tls',
    );
  }

  // ---- Chainable API ----
  Mail to(String email) {
    _to.add(email);
    return this;
  }

  Mail toMany(List<String> emails) {
    _to.addAll(emails);
    return this;
  }

  Mail cc(String email) {
    _cc.add(email);
    return this;
  }

  Mail ccMany(List<String> emails) {
    _cc.addAll(emails);
    return this;
  }

  Mail bcc(String email) {
    _bcc.add(email);
    return this;
  }

  Mail bccMany(List<String> emails) {
    _bcc.addAll(emails);
    return this;
  }

  Mail subject(String subject) {
    _subject = subject;
    return this;
  }

  Mail html(String html) {
    _html = html;
    return this;
  }

  Mail text(String text) {
    _text = text;
    return this;
  }

  Mail replyTo(String email) {
    _replyTo = email;
    return this;
  }

  // ---- Message builder ----
  Message _buildMessage() {
    if (_to.isEmpty && _cc.isEmpty && _bcc.isEmpty) {
      throw Exception('No recipients specified.');
    }

    if (_subject == null && _text == null && _html == null) {
      throw Exception('Message has no content.');
    }

    if (_fromAddress == null || _fromAddress!.isEmpty) {
      throw Exception('From address not set. Call Mail.setup() first.');
    }

    Log.debug('Building message from $_fromName <$_fromAddress> to $_to');

    final msg = Message()
      ..from = Address(_fromAddress!, _fromName ?? 'Flint Dart')
      ..recipients.addAll(_to)
      ..ccRecipients.addAll(_cc)
      ..bccRecipients.addAll(_bcc)
      ..subject = _subject ?? '';

    final replyAddress = _replyTo ?? _defaultReplyTo;
    if (replyAddress != null && replyAddress.isNotEmpty) {
      msg.headers['Reply-To'] = replyAddress;
    }

    if (_html != null && _text == null) {
      final plain = _html!
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .trim();
      msg.text = plain;
    } else if (_text != null) {
      msg.text = _text;
    }

    if (_html != null) msg.html = _html;

    return msg;
  }

  Future<bool> _retryAfterReconfigure() async {
    try {
      _ensureConfigured(forceReload: true);
      if (_server == null) return false;

      final retryMsg = _buildMessage();
      await send(retryMsg, _server!);
      Log.debug('Mail sent after automatic mail reconfiguration');
      return true;
    } catch (_) {
      return false;
    }
  }

  // ---- Send immediately ----
  Future<void> sendMail() async {
    _ensureConfigured();

    if (_server == null) {
      throw Exception('Mail not configured. Call Mail.setup() first.');
    }

    try {
      final msg = _buildMessage();
      await send(msg, _server!);
      Log.debug('Mail sent to: ${_to.join(', ')}');
    } on MailerException catch (e) {
      final recovered = await _retryAfterReconfigure();
      if (recovered) return;

      Log.debug('MailerException: $e');
      if (e.problems.isNotEmpty) {
        for (final problem in e.problems) {
          Log.debug('  - ${problem.code}: ${problem.msg}');
        }
      }
      rethrow;
    } on SocketException catch (e) {
      final recovered = await _retryAfterReconfigure();
      if (recovered) return;

      Log.debug('SocketException while sending mail: $e');
      rethrow;
    } catch (e) {
      Log.debug('Failed to send mail: $e');
      rethrow;
    }
  }

  // ---- Send asynchronously (background isolate) ----
  Future<void> queue() async {
    _ensureConfigured();

    if (_server == null) {
      throw Exception('Mail not configured. Call Mail.setup() first.');
    }

    final mailData = {
      'fromAddress': _fromAddress,
      'fromName': _fromName,
      'replyTo': _replyTo ?? _defaultReplyTo,
      'to': _to,
      'cc': _cc,
      'bcc': _bcc,
      'subject': _subject,
      'text': _text,
      'html': _html,
    };

    final serverData = {
      'host': _server!.host,
      'port': _server!.port,
      'username': _server!.username,
      'password': _server!.password,
      'ssl': _server!.ssl,
    };

    await Isolate.spawn(_sendInBackground, {
      'message': mailData,
      'server': serverData,
    });
  }

  // ---- Background worker ----
  static Future<void> _sendInBackground(Map data) async {
    final msgData = Map<String, dynamic>.from(data['message']);
    final serverData = Map<String, dynamic>.from(data['server']);

    final msg = Message()
      ..from = Address(
        msgData['fromAddress'] ?? 'noreply@domain.com',
        msgData['fromName'] ?? 'Flint Dart',
      )
      ..recipients.addAll(List<String>.from(msgData['to'] ?? []))
      ..ccRecipients.addAll(List<String>.from(msgData['cc'] ?? []))
      ..bccRecipients.addAll(List<String>.from(msgData['bcc'] ?? []))
      ..subject = msgData['subject'] ?? ''
      ..text = msgData['text']
      ..html = msgData['html'];

    final replyAddress = msgData['replyTo']?.toString();
    if (replyAddress != null && replyAddress.isNotEmpty) {
      msg.headers['Reply-To'] = replyAddress;
    }

    final server = SmtpServer(
      serverData['host'],
      port: serverData['port'],
      username: serverData['username'],
      password: serverData['password'],
      ssl: serverData['ssl'],
    );

    try {
      await send(msg, server);
      Log.debug('Queued mail sent to: ${msg.recipients.join(', ')}');
    } catch (e) {
      Log.debug('Queued mail failed: $e');
    }
  }
}
