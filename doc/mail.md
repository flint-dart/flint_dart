# Mail

Flint mail is the framework layer for SMTP configuration, direct message sending, queued/background sending, and HTML email templates rendered from `.flint.html` views. Authentication OTP emails, password reset emails, invoices, admin broadcasts, and service notifications should all use this layer instead of building raw SMTP messages in controllers.

Before coding mail in an app, inspect these files:

- `.env`
- `lib/main.dart`
- `lib/mail/`
- `lib/mail/views/`
- `lib/services/mail/`
- `lib/jobs/`
- `lib/controllers/*email*_controller.dart`
- `lib/routes/*email*_routes.dart`

For OTP and auth mail, also read `docs/authentication.md`.
For the complete `{{ }}` template language, includes, layouts, sections,
control flow, assets, sessions, comments, and mail-template syntax, read
`docs/templates.md`.

## Framework Source References

Framework code to inspect when behavior is unclear:

- `lib/src/mail/mail.dart`
- `lib/src/mail/mail_config.dart`
- `lib/src/mail/view_mailable.dart`
- `lib/src/mail/mailable.dart`
- `lib/src/mail/smtp_factory.dart`
- `lib/src/template_engine/template.dart`
- `lib/src/template_engine/template_reader.dart`
- `lib/src/response.dart`
- `lib/src/cli/make_mail_command.dart`

Generated apps should keep their own sender names, subjects, support URLs, template tone, and feature flags.

## Framework Pieces

Use this export:

```dart
import 'package:flint_dart/mail.dart';
```

The main APIs are:

- `MailConfig.load()`
- `Mail.setup(...)`
- `Mail().to(...).subject(...).html(...).sendMail()`
- `Mail().to(...).subject(...).text(...).sendMail()`
- `Mail().to(...).subject(...).html(...).queue()`
- `ViewMailable`
- `MailPriority`
- `MailAttachment`
- `res.renderEmail(...)`

`Flint(autoConnectMail: true)` is the default. When the HTTP server starts, Flint calls `MailConfig.load()` and configures mail from `.env`. The jobs worker also loads mail when `autoConnectMail` is enabled.

In background isolates or standalone tool scripts, call `MailConfig.load()` before sending because static mail configuration is isolate-local.
Read `docs/isolate-tasks.md` before moving mail work into an `IsolateTask`;
for durable mail delivery, prefer a `QueueJob`.

```dart
Future<void> performTask() async {
  MailConfig.load();
  await DB.autoConnect();
  await ReminderMail(...).send();
}
```

## Environment

`MailConfig.load()` and `Mail._ensureConfigured()` read these values:

```text
MAIL_PROVIDER=custom
MAIL_HOST=smtp.example.com
MAIL_PORT=587
MAIL_USERNAME=mailer@example.com
MAIL_PASSWORD=replace-with-real-password
MAIL_ENCRYPTION=tls
MAIL_FROM_NAME=My App
MAIL_FROM_ADDRESS=noreply@example.com
MAIL_REPLY_TO=support@example.com
```

Supported provider names are:

- `gmail`
- `outlook`
- `yahoo`
- `custom`

For ordinary SMTP servers, use `MAIL_PROVIDER=custom`. Some existing apps use `MAIL_PROVIDER=smtp`; the current parser falls back to `custom` for unknown names, but new docs and examples should prefer `custom`.

Use `MAIL_ENCRYPTION=tls` for port `587` and `MAIL_ENCRYPTION=ssl` for port `465`, unless the provider tells you otherwise.

Do not commit real SMTP usernames, passwords, app passwords, or mailbox secrets. Use placeholders in docs, tests, and examples.

## Direct Mail

Use direct `Mail` when the body is already known or when a service builds HTML dynamically.

```dart
await Mail()
    .to('customer@example.com')
    .subject('Welcome')
    .html('<p>Your account is ready.</p>')
    .sendMail();
```

Plain text:

```dart
await Mail()
    .to('customer@example.com')
    .subject('Welcome')
    .text('Your account is ready.')
    .sendMail();
```

Multiple recipients:

```dart
await Mail()
    .toMany(['a@example.com', 'b@example.com'])
    .cc('manager@example.com')
    .bcc('audit@example.com')
    .replyTo('support@example.com')
    .subject('Service notice')
    .html('<p>We updated your service.</p>')
    .sendMail();
```

`Mail.sendMail()` builds a `mailer` package `Message` and sends it through the configured SMTP server. If only HTML is set, Flint also creates a plain-text fallback by stripping tags.

## Queued Mail

`Mail.queue()` sends through a background isolate:

```dart
await Mail()
    .to('customer@example.com')
    .subject('Background send')
    .html('<p>This mail is sent outside the request path.</p>')
    .queue();
```

Queued mail is useful when an HTTP response should not wait for SMTP. For application job queues, prefer dispatching a `QueueJob` and sending inside the job with `MailConfig.load()` and `DB.autoConnect()`.

## ViewMailable

Use `ViewMailable` for transactional emails. It keeps the subject, recipients, view path, and template data in one class.

Generate a starter mail with:

```bash
dart run flint_dart:flint --make-mail welcome
```

The older `make:mail` alias is deprecated and will be removed in Flint Dart
`1.5.0`; use `--make-mail` in new examples and generated guidance.

That creates:

```text
lib/mail/welcome_mail.dart
lib/mail/views/welcome.flint.html
```

Manual example:

```dart
class WelcomeMail extends ViewMailable {
  WelcomeMail({
    required this.recipientName,
    required this.recipientEmail,
  });

  final String recipientName;
  final String recipientEmail;

  @override
  String get subject => 'Welcome to My App';

  @override
  String get view => 'mail/views/welcome.flint.html';

  @override
  Map<String, dynamic> get data => {
        'recipientName': recipientName,
        'currentYear': DateTime.now().year,
      };

  @override
  List<String> get to => [recipientEmail];
}
```

Send it:

```dart
await WelcomeMail(
  recipientName: user.firstName,
  recipientEmail: user.email,
).send();
```

Queue it:

```dart
await WelcomeMail(
  recipientName: user.firstName,
  recipientEmail: user.email,
).queue();
```

## Template Paths

Put mail templates in:

```text
lib/mail/views/*.flint.html
```

In `ViewMailable.view`, use:

```dart
String get view => 'mail/views/welcome.flint.html';
```

The template reader tries direct relative paths, paths relative to `lib/`, and logical view paths. The `mail/views/name.flint.html` style is the clearest for generated apps.

Template variables use the Flint template engine:

```html
<h2>Hello {{ recipientName }}</h2>
<p>Your invoice {{ invoiceId }} is ready.</p>
<p>&copy; {{ currentYear }} {{ brandName }}</p>
```

## Template Syntax

`{{ ... }}` tells Flint to evaluate something from the `ViewMailable.data` map and place the result in the rendered HTML.

Given this mail data:

```dart
@override
Map<String, dynamic> get data => {
      'recipientName': 'Ada',
      'otp': '123456',
      'expiresInMinutes': 10,
      'invoice': {
        'id': 'INV-1001',
        'total': '150.00',
      },
      'displayName': '',
      'items': [
        {'name': 'Starter Hosting', 'price': '50.00'},
        {'name': 'Domain Renewal', 'price': '100.00'},
      ],
    };
```

Use simple variables like this:

```html
<p>Hello {{ recipientName }}</p>
<p>Your OTP is {{ otp }}</p>
<p>This code expires in {{ expiresInMinutes }} minutes.</p>
```

Use nested map values with dot paths:

```html
<p>Invoice {{ invoice.id }}</p>
<p>Total: {{ invoice.total }}</p>
```

Use list indexes when you need a specific item:

```html
<p>First item: {{ items[0].name }}</p>
```

Use filters with `|`:

```html
<p>{{ recipientName | uppercase }}</p>
<p>{{ displayName | default:"Customer" }}</p>
<script>
  const items = {{ items | json }};
</script>
```

Useful filters include:

- `default:"value"`
- `uppercase`
- `lowercase`
- `capitalize`
- `length`
- `string`
- `bool`
- `json`
- `join:","`
- `first`
- `flatten`
- `raw`

Use conditionals:

```html
{{ if invoice.total > 0 }}
  <p>Amount due: {{ invoice.total }}</p>
{{ else }}
  <p>No payment is due.</p>
{{ endif }}
```

`elseif` is also supported:

```html
{{ if status == "paid" }}
  <p>Payment received.</p>
{{ elseif status == "pending" }}
  <p>Payment is pending.</p>
{{ else }}
  <p>Status: {{ status }}</p>
{{ endif }}
```

Use loops for lists:

```html
<ul>
  {{ for item in items }}
    <li>{{ index }}. {{ item.name }} - {{ item.price }}</li>
  {{ endfor }}
</ul>
```

Use a C-style loop when index-based access is clearer:

```html
{{ for i=0; i<3; i++ }}
  <p>Item {{ i }}: {{ items[i].name }}</p>
{{ endfor }}
```

Use comments for template-only notes:

```html
{{! This comment is removed }}
{{# This comment is also removed #}}
```

Use includes for shared fragments:

```html
{{ include('mail/views/partials/footer.flint.html') }}
{{ include('mail/views/partials/button.flint.html', {"label": "Open invoice"}) }}
```

For includes with data, pass JSON-style keys and values. The include receives the parent data plus the values you pass.

Important safety notes:

- `{{ value }}` is not an HTML-escaping helper. If a value came from a user or admin form, sanitize it or escape it before putting it in `data`.
- Use `| json` when placing maps or lists inside JavaScript.
- Keep inline CSS simple because email clients do not behave like normal browsers.
- Do not put real OTP values in preview routes, docs, tests, or screenshots.
- If a simple variable is missing, Flint can render the expression text. For
  customer-facing copy, pass a null or empty value intentionally and use
  `default:"..."`.

The template engine also supports sections, layouts with `extends`, sessions, old form values, and asset helpers. For mail templates, keep the surface small: variables, conditions, loops, includes, and simple filters are usually enough.

## OTP Mail

OTP mail should be a `ViewMailable` with a purpose enum. Keep code generation/verification in `Auth`; keep delivery wording in the mailable.

```dart
enum OTPPurpose {
  emailVerification,
  passwordReset,
  resend,
  twoFactorLogin,
  twoFactorSetup,
  newDeviceLoginVerification,
}

class OTPVerificationMail extends ViewMailable {
  OTPVerificationMail({
    required this.recipientName,
    required this.recipientEmail,
    required this.otp,
    required this.purpose,
    this.expiresInMinutes = 10,
  });

  final String recipientName;
  final String recipientEmail;
  final String otp;
  final OTPPurpose purpose;
  final int expiresInMinutes;

  @override
  String get subject => switch (purpose) {
        OTPPurpose.emailVerification => 'Verify your email address',
        OTPPurpose.passwordReset => 'Reset your password',
        OTPPurpose.resend => 'Your new verification code',
        OTPPurpose.twoFactorLogin => 'Your two-factor login code',
        OTPPurpose.twoFactorSetup => 'Confirm two-factor setup',
        OTPPurpose.newDeviceLoginVerification => 'Verify new device login',
      };

  @override
  String get view => 'mail/views/otp.flint.html';

  @override
  Map<String, dynamic> get data => {
        'recipientName': recipientName,
        'otp': otp,
        'expiresInMinutes': expiresInMinutes,
        'title': subject,
        'message': _message,
        'securityNotice': _securityNotice,
        'currentYear': DateTime.now().year,
      };

  @override
  List<String> get to => [recipientEmail];

  String get _message => switch (purpose) {
        OTPPurpose.emailVerification =>
          'Use the code below to verify your email address.',
        OTPPurpose.passwordReset =>
          'Use the code below to reset your password.',
        OTPPurpose.resend => 'Here is your new verification code.',
        OTPPurpose.twoFactorLogin =>
          'Use the code below to complete your sign in.',
        OTPPurpose.twoFactorSetup =>
          'Use this code to enable email-based two-factor authentication.',
        OTPPurpose.newDeviceLoginVerification =>
          'Use this code to confirm the login was yours.',
      };

  String get _securityNotice => switch (purpose) {
        OTPPurpose.passwordReset =>
          'If you did not request a password reset, secure your account.',
        OTPPurpose.twoFactorLogin ||
        OTPPurpose.newDeviceLoginVerification =>
          'If this login was not you, change your password.',
        OTPPurpose.twoFactorSetup =>
          'If you did not request 2FA setup, contact support.',
        OTPPurpose.emailVerification ||
        OTPPurpose.resend =>
          'If you did not request this code, you can ignore this email.',
      };
}
```

Template:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <title>{{ title }}</title>
</head>
<body>
  <h2>Hello {{ recipientName }}</h2>
  <p>{{ message }}</p>
  <div style="font-size:28px;letter-spacing:4px;font-weight:bold;">
    {{ otp }}
  </div>
  <p>This code expires in {{ expiresInMinutes }} minutes.</p>
  <p>{{ securityNotice }}</p>
  <p>&copy; {{ currentYear }}</p>
</body>
</html>
```

Send:

```dart
final otp = await Auth.generateNumericVerificationCode(user.email);

await OTPVerificationMail(
  recipientName: user.firstName,
  recipientEmail: user.email,
  otp: otp,
  purpose: OTPPurpose.emailVerification,
).send();
```

Do not log the returned OTP. The framework stores only a hash and expiry.

## Previewing Mail

Use the response instance method `res.renderEmail(...)` to preview a `ViewMailable` in the browser without sending SMTP mail.

```dart
app.get('/preview/email/otp', (Context ctx) async {
  return ctx.res?.renderEmail(
    OTPVerificationMail(
      recipientName: 'Preview User',
      recipientEmail: 'preview@example.com',
      otp: '123456',
      purpose: OTPPurpose.emailVerification,
    ),
  );
});
```

Preview routes should not expose real customer data or real OTPs. Use fixed demo values.

## Shared Base Mail

Larger apps should add a base class for common template data instead of repeating `brandName`, support links, or `currentYear` in every mail class.

```dart
abstract class BaseViewMailable extends ViewMailable {
  @override
  Map<String, dynamic> get data => {
        'currentYear': DateTime.now().year,
        'brandName': 'My App',
        'supportUrl': 'https://example.com/support',
        ...mailData,
      };

  Map<String, dynamic> get mailData;
}
```

Then each mail only supplies its own fields:

```dart
class PaymentSuccessMail extends BaseViewMailable {
  PaymentSuccessMail({
    required this.recipientName,
    required this.recipientEmail,
    required this.amount,
  });

  final String recipientName;
  final String recipientEmail;
  final double amount;

  @override
  String get subject => 'Payment received successfully';

  @override
  String get view => 'mail/views/payment_success.flint.html';

  @override
  Map<String, dynamic> get mailData => {
        'recipientName': recipientName,
        'amount': amount.toStringAsFixed(2),
      };

  @override
  List<String> get to => [recipientEmail];
}
```

## Delivery Policy

Production apps often need switches that suppress customer mail during maintenance, impersonation, local testing, or dry runs. Keep that logic outside individual controllers.

```dart
class MailDeliveryPolicy {
  static bool customerEmailsEnabled() {
    final raw = FlintEnv.get('EMAIL_CUSTOMER_MAILS_ENABLED', 'true');
    return raw == 'true' || raw == '1' || raw == 'yes' || raw == 'on';
  }

  static List<String> customerRecipients(String email) {
    if (!customerEmailsEnabled()) return const <String>[];
    final trimmed = email.trim();
    return trimmed.isEmpty ? const <String>[] : <String>[trimmed];
  }
}
```

A mixin can prevent customer mail from sending while preserving the normal `ViewMailable` API:

```dart
mixin CustomerMailSuppressionMixin on ViewMailable {
  @override
  Future<void> send() async {
    if (!MailDeliveryPolicy.customerEmailsEnabled()) {
      Log.info('[MAIL_DISABLED] Skipped send');
      return;
    }
    await super.send();
  }

  @override
  Future<void> queue() async {
    if (!MailDeliveryPolicy.customerEmailsEnabled()) {
      Log.info('[MAIL_DISABLED] Skipped queue');
      return;
    }
    await super.queue();
  }
}
```

Then transactional mails can opt in:

```dart
class OTPVerificationMail extends ViewMailable
    with CustomerMailSuppressionMixin {
  // ...
}
```

Admin or internal alert emails may use a different policy from customer emails.

## Admin Broadcasts

When users or admins provide email HTML:

1. Validate required fields.
2. Restrict recipients to known users or configured internal recipients.
3. Sanitize HTML before storage or sending.
4. Limit message size.
5. Store an email log row before sending.
6. Dispatch a job for the actual send.
7. Record sent and failed counts.

Directly sending untrusted HTML from a request is risky. Strip script-like tags, inline event handlers, unsafe URLs, and embedded form controls.

## Attachments And Current Limits

`MailAttachment` exists as a value object and `ViewMailable.attachments` exists on the interface, but the current `ViewMailable.send()` path does not attach files to the outgoing `Mail` object. Inspect `lib/src/mail/view_mailable.dart` and `lib/src/mail/mail.dart` before relying on attachments.

`ViewMailable.send()` applies `cc` and `bcc`; `ViewMailable.queue()` currently sends only `to`, subject, HTML, and text. If queued CC/BCC matters, update the framework first and add tests.

## Auth And Mail Together

For auth flows:

- Use `Auth.generateNumericVerificationCode(email)` for email verification, email 2FA, and new-device login checks.
- Use `Auth.generatePasswordResetCode(email)` for password-reset OTPs.
- Send the returned code immediately with a `ViewMailable`.
- Verify with the matching `Auth.verify*` method.
- Keep endpoint response messages generic enough that attackers cannot easily enumerate accounts.
- Add rate limiting around register, login, forgot-password, resend, and verify routes.

See `docs/authentication.md` for full auth controller and service examples.

## Troubleshooting

- `Mail not configured. Call Mail.setup() first.` means `MailConfig.load()` was not called or the `.env` values are missing in this isolate.
- `From address not set` means `MAIL_FROM_ADDRESS` is missing or empty.
- SMTP connection failures usually mean host, port, encryption, username, or password is wrong.
- Gmail usually needs provider `gmail`, port `587`, TLS, and an app password.
- Custom SMTP on port `465` usually needs `MAIL_ENCRYPTION=ssl`.
- Template-not-found errors list every path Flint tried. Check `ViewMailable.view` and `lib/mail/views`.
- If mail sends locally but not from a job, call `MailConfig.load()` inside the job worker or isolate.
- If customer email is skipped, inspect the app's mail delivery policy and feature flags.

## Implementation Checklist

When working on mail:

1. Read `docs/mail.md`; for OTP/auth mail also read `docs/authentication.md`.
2. Inspect `lib/mail/`, `lib/mail/views/`, `lib/services/mail/`, and any job that sends the mail.
3. Confirm SMTP env names and avoid exposing secrets.
4. Use `ViewMailable` for reusable transactional email.
5. Use direct `Mail()` for short dynamic or admin-created messages.
6. Load mail config in isolates, jobs, and standalone tools.
7. Preview templates with `res.renderEmail(...)` using safe demo data.
8. Respect delivery policies and customer-mail suppression.
9. Add tests for template data, recipients, suppression behavior, or jobs when the flow is business-critical.
