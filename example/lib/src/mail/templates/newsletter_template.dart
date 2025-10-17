// lib/mail/templates/newsletter_template.dart

import 'package:flint_dart/flint_ui.dart';

class NewsletterTemplate extends FlintEmailTemplate {
  final String title;
  final String content;
  final String? imageUrl;
  final String? ctaUrl;
  final String? ctaText;

  NewsletterTemplate({
    required this.title,
    required this.content,
    this.imageUrl,
    this.ctaUrl,
    this.ctaText = 'Learn More',
    super.theme = const FlintTheme(),
  }) : super(
          recipientName: 'Subscriber',
          recipientEmail: 'newsletter@example.com',
        );

  @override
  FlintWidget buildContent() {
    return FlintBox(
      padding: EdgeInsets.all(0),
      children: [
        // Hero image
        if (imageUrl != null) _buildHeroImage(),

        // Content
        FlintBox(
          padding: EdgeInsets.all(24),
          children: [
            // Title
            _buildTitle(),

            // Content
            _buildContent(),

            // CTA
            if (ctaUrl != null) _buildCTA(),

            // Footer
            _buildFooter(),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildHeroImage() {
    return FlintImage(
      src: imageUrl!,
      alt: title,
      width: 600,
      height: 200,
      style: const ImageStyle(fit: ObjectFit.cover),
    );
  }

  FlintWidget _buildTitle() {
    return FlintBox(
      children: [
        FlintText(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: '#1a1a1a',
          ),
          align: TextAlign.center,
        ),
      ],
    );
  }

  FlintWidget _buildContent() {
    return FlintBox(
      margin: EdgeInsets.only(top: 16),
      children: [
        FlintText(
          content,
          style: TextStyle(
            fontSize: 14,
            color: '#666666',
            // lineHeight: 1.6,
          ),
          align: TextAlign.center,
        ),
      ],
    );
  }

  FlintWidget _buildCTA() {
    return FlintBox(
      margin: EdgeInsets.only(top: 24),
      children: [
        FlintButton(
          text: ctaText!,
          url: ctaUrl!,
          style: ButtonStyle.primary().copyWith(
            backgroundColor: theme.primaryColor,
            textStyle: TextStyle(
              color: '#ffffff',
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          borderRadius: BorderRadius.circular(6),
        ),
      ],
    );
  }

  FlintWidget _buildFooter() {
    return FlintBox(
      margin: EdgeInsets.only(top: 32),
      padding: EdgeInsets.all(16),
      backgroundColor: '#f8f9fa',
      borderRadius: BorderRadius.circular(6),
      children: [
        FlintText(
          'You received this email because you subscribed to our newsletter.',
          style: TextStyle(
            fontSize: 12,
            color: '#666666',
          ),
          align: TextAlign.center,
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 8),
          children: [
            FlintRichText(
              children: [
                FlintTextSpan(
                  'Unsubscribe',
                  style: TextStyle(
                    color: '#999999',
                    decoration: TextDecoration.underline,
                  ),
                  onTap: 'https://example.com/unsubscribe',
                ),
              ],
              align: TextAlign.center,
            ),
          ],
        ),
      ],
    );
  }
}
