// lib/mail/templates/welcome_mail_template.dart

import 'package:flint_dart/flint_ui.dart';

class WelcomeMailTemplate extends FlintEmailTemplate {
  final String verificationUrl;
  final String loginUrl;
  final String? supportEmail;
  final String? supportPhone;

  WelcomeMailTemplate({
    required super.recipientName,
    required super.recipientEmail,
    required this.verificationUrl,
    required this.loginUrl,
    this.supportEmail = 'support@example.com',
    this.supportPhone = '+1 (555) 123-4567',
    super.theme = const FlintTheme(),
  });

  @override
  FlintWidget buildContent() {
    return FlintBox(
      padding: EdgeInsets.all(24),
      children: [
        // Welcome header
        _buildWelcomeHeader(),

        // Spacer
        FlintBox(
          margin: EdgeInsets.symmetric(vertical: 24),
          children: [
            FlintBox(
                constraints: BoxConstraints.tightFor(height: 1),
                backgroundColor: '#e0e0e0',
                children: [])
          ],
        ),

        // Verification section
        _buildVerificationSection(),

        // Spacer
        FlintBox(
          margin: EdgeInsets.symmetric(vertical: 24),
          children: [
            FlintBox(
                constraints: BoxConstraints.tightFor(height: 1),
                backgroundColor: '#e0e0e0',
                children: [])
          ],
        ),

        // Features section
        _buildFeaturesSection(),

        // Spacer
        FlintBox(
          margin: EdgeInsets.symmetric(vertical: 24),
          children: [
            FlintBox(
                constraints: BoxConstraints.tightFor(height: 1),
                backgroundColor: '#e0e0e0',
                children: [])
          ],
        ),

        // Support section
        _buildSupportSection(),
      ],
    );
  }

  FlintWidget _buildWelcomeHeader() {
    return FlintBox(
      children: [
        FlintText(
          'Welcome to Our Service, $recipientName! 🎉',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: '#1a1a1a',
          ),
          align: TextAlign.center,
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 16),
          children: [
            FlintText(
              'We\'re thrilled to have you join our community. '
              'Your account has been successfully created and you\'re all set to get started.',
              style: TextStyle(
                fontSize: 16,
                color: '#666666',
                // lineHeight: 1.6,
              ),
              align: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildVerificationSection() {
    return FlintBox(
      children: [
        FlintText(
          'Verify Your Email Address',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: '#1a1a1a',
          ),
          align: TextAlign.center,
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 16),
          children: [
            FlintText(
              'Please verify your email address to activate your account '
              'and access all features. This helps us keep your account secure.',
              style: TextStyle(
                fontSize: 14,
                color: '#666666',
                // lineHeight: 1.6,
              ),
              align: TextAlign.center,
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 24),
          children: [
            FlintButton(
              text: 'Verify Email Address',
              url: verificationUrl,
              style: ButtonStyle.primary().copyWith(
                backgroundColor: theme.primaryColor,
                textStyle: TextStyle(
                    color: '#ffffff',
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                    backgroundColor: "#4eca78"),
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
              align: TextAlign.center,
            ),
            FlintBox(
              margin: EdgeInsets.only(top: 8),
              children: [
                FlintText(
                  verificationUrl,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.primaryColor,
                    decoration: TextDecoration.underline,
                  ),
                  align: TextAlign.center,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildFeaturesSection() {
    return FlintBox(
      children: [
        FlintText(
          'What You Can Do Now',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: '#1a1a1a',
          ),
          align: TextAlign.center,
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 20),
          children: [
            FlintRow(
              columnWidths: [33, 33, 33],
              children: [
                _buildFeatureItem(
                  icon: '🚀',
                  title: 'Get Started',
                  description:
                      'Explore all features immediately after verification',
                ),
                _buildFeatureItem(
                  icon: '🔒',
                  title: 'Secure Account',
                  description:
                      'Your data is protected with enterprise-grade security',
                ),
                _buildFeatureItem(
                  icon: '💬',
                  title: '24/7 Support',
                  description: 'Get help whenever you need it from our team',
                ),
              ],
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 24),
          children: [
            FlintButton(
              text: 'Explore Dashboard',
              url: loginUrl,
              style: ButtonStyle.outline().copyWith(
                textStyle: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                border: BoxBorder(
                  color: theme.primaryColor,
                  width: 2,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              borderRadius: BorderRadius.circular(6),
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildFeatureItem({
    required String icon,
    required String title,
    required String description,
  }) {
    return FlintBox(
      padding: EdgeInsets.all(16),
      children: [
        FlintText(
          icon,
          style: TextStyle(fontSize: 32),
          align: TextAlign.center,
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 12),
          children: [
            FlintText(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: '#1a1a1a',
              ),
              align: TextAlign.center,
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 8),
          children: [
            FlintText(
              description,
              style: TextStyle(
                fontSize: 12,
                color: '#666666',
                // lineHeight: 1.5,
              ),
              align: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildSupportSection() {
    return FlintBox(
      children: [
        FlintText(
          'Need Help?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: '#1a1a1a',
          ),
          align: TextAlign.center,
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 16),
          children: [
            FlintRichText(
              children: [
                FlintTextSpan('Email: '),
                FlintTextSpan(
                  supportEmail!,
                  style: TextStyle(color: theme.primaryColor),
                  onTap: 'mailto:$supportEmail',
                ),
              ],
              align: TextAlign.center,
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 8),
          children: [
            FlintRichText(
              children: [
                FlintTextSpan('Phone: '),
                FlintTextSpan(
                  supportPhone!,
                  style: TextStyle(color: theme.primaryColor),
                  onTap: 'tel:$supportPhone',
                ),
              ],
              align: TextAlign.center,
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 16),
          children: [
            FlintText(
              'We\'re here to help you get started and make the most of our service.',
              style: TextStyle(
                fontSize: 12,
                color: '#666666',
                // fontStyle: FontStyle.italic,
              ),
              align: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }
}
