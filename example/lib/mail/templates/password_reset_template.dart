// lib/mail/templates/password_reset_template.dart

import 'package:flint_dart/flint_ui.dart';

class PasswordResetTemplate extends FlintEmailTemplate {
  final String resetUrl;
  final int expiryHours;

  PasswordResetTemplate({
    required super.recipientName,
    required super.recipientEmail,
    required this.resetUrl,
    this.expiryHours = 24,
    super.theme = const FlintTheme(),
  });

  @override
  FlintWidget buildContent() {
    return FlintBox(
      padding: EdgeInsets.all(24),
      children: [
        // Header
        _buildHeader(),

        // Reset section
        _buildResetSection(),

        // Security notice
        _buildSecurityNotice(),

        // Support
        _buildSupportSection(),
      ],
    );
  }

  FlintWidget _buildHeader() {
    return FlintBox(
      children: [
        FlintText(
          'Password Reset Request',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: '#1a1a1a',
          ),
          align: TextAlign.center,
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 16),
          children: [
            FlintText(
              'Hello $recipientName,',
              style: TextStyle(
                fontSize: 16,
                color: '#666666',
              ),
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildResetSection() {
    return FlintBox(
      margin: EdgeInsets.only(top: 24),
      children: [
        FlintText(
          'We received a request to reset your password. Click the button below to create a new one:',
          style: TextStyle(
            fontSize: 14,
            color: '#666666',
          ),
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 24),
          children: [
            FlintButton(
              text: 'Reset Password',
              url: resetUrl,
              style: ButtonStyle.primary().copyWith(
                backgroundColor: '#dc3545', // Red for urgency
                textStyle: TextStyle(
                  color: '#ffffff',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              borderRadius: BorderRadius.circular(8),
              fullWidth: true,
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 16),
          children: [
            FlintText(
              'Or copy and paste this link in your browser:',
              style: TextStyle(
                fontSize: 12,
                color: '#999999',
              ),
            ),
            FlintBox(
              margin: EdgeInsets.only(top: 8),
              children: [
                FlintText(
                  resetUrl,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.primaryColor,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildSecurityNotice() {
    return FlintBox(
      margin: EdgeInsets.only(top: 24),
      padding: EdgeInsets.all(16),
      backgroundColor: '#fff3cd',
      border: BoxBorder.all(color: '#ffeaa7'),
      borderRadius: BorderRadius.circular(6),
      children: [
        FlintText(
          '🔒 Security Notice',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: '#856404',
          ),
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 8),
          children: [
            FlintText(
              'This password reset link will expire in $expiryHours hours. '
              'If you didn\'t request a password reset, please ignore this email '
              'and ensure your account is secure.',
              style: TextStyle(
                fontSize: 12,
                color: '#856404',
              ),
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildSupportSection() {
    return FlintBox(
      margin: EdgeInsets.only(top: 24),
      children: [
        FlintText(
          'If you have any questions or need assistance, please contact our support team.',
          style: TextStyle(
            fontSize: 12,
            color: '#666666',
            // fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}
