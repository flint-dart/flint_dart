// lib/flint_ui/core/base_templates.dart

import 'package:flint_dart/flint_ui.dart';
import 'package:flint_dart/src/flint_ui/core/theme.dart';

/// Base class for all email templates with common structure
abstract class FlintEmailTemplate extends FlintTemplate {
  final String recipientName;
  final String recipientEmail;
  final FlintTheme theme;

  FlintEmailTemplate({
    required this.recipientName,
    required this.recipientEmail,
    this.theme = const FlintTheme(),
  });

  /// Common header for all emails
  FlintWidget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      children: [
        Image(
          src: 'https://example.com/logo.png',
          alt: 'Company Logo',
          width: 120,
        ),
      ],
    );
  }

  /// Common footer for all emails
  FlintWidget _buildFooter() {
    return Container(
      padding: EdgeInsets.all(20),
      backgroundColor: '#f8f9fa',
      children: [
        Text(
          '© ${DateTime.now().year} Your Company. All rights reserved.',
          style: TextStyle(
            fontSize: 12,
            color: '#666666',
          ),
          align: TextAlign.center,
        ),
        Container(
          margin: EdgeInsets.only(top: 8),
          children: [
            // Text(
            //   children: [
            //     Text('Contact: '),
            //     Text(
            //       'support@example.com',
            //       onTap: 'mailto:support@example.com',
            //       style: TextStyle(color: theme.primaryColor),
            //     ),
            //   ],
            //   align: TextAlign.center,
            // ),
          ],
        ),
      ],
    );
  }

  /// Build the main content - MUST be implemented by subclasses
  FlintWidget buildContent();

  /// Final template assembly
  @override
  FlintWidget buildTemplate() {
    return Container(
      constraints: BoxConstraints(maxWidth: 600),
      backgroundColor: '#ffffff',
      children: [
        _buildHeader(),
        buildContent(),
        _buildFooter(),
      ],
    );
  }
}

/// Base class for notification templates
abstract class FlintNotificationTemplate extends FlintEmailTemplate {
  FlintNotificationTemplate({
    required super.recipientName,
    required super.recipientEmail,
    super.theme,
  });

  /// Notification-specific styling
  @override
  FlintWidget buildTemplate() {
    return Container(
      constraints: BoxConstraints(maxWidth: 500),
      backgroundColor: '#ffffff',
      border: BoxBorder.all(color: '#e0e0e0'),
      borderRadius: BorderRadius.circular(8),
      children: [
        buildContent(),
      ],
    );
  }
}

/// Base class for marketing templates
abstract class FlintMarketingTemplate extends FlintEmailTemplate {
  FlintMarketingTemplate({
    required super.recipientName,
    required super.recipientEmail,
    super.theme,
  });

  /// Marketing-specific styling with more visual elements
  @override
  FlintWidget buildTemplate() {
    return Container(
      constraints: BoxConstraints(maxWidth: 600),
      backgroundColor: '#ffffff',
      children: [
        _buildMarketingHeader(),
        buildContent(),
        _buildMarketingFooter(),
      ],
    );
  }

  FlintWidget _buildMarketingHeader() {
    return Container(
      padding: EdgeInsets.all(30),
      backgroundColor: theme.primaryColor,
      children: [
        Text(
          'Special Offer Inside!',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: '#ffffff',
          ),
          align: TextAlign.center,
        ),
      ],
    );
  }

  FlintWidget _buildMarketingFooter() {
    return Container(
      padding: EdgeInsets.all(20),
      backgroundColor: '#2d3748',
      children: [
        Text(
          'Don\'t miss out on our latest offers!',
          style: TextStyle(
            fontSize: 14,
            color: '#ffffff',
          ),
          align: TextAlign.center,
        ),
      ],
    );
  }
}
