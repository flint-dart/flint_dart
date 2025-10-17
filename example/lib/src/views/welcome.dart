import 'package:flint_dart/flint_ui.dart';

class Welcome extends FlintTemplate {
  @override
  FlintWidget buildTemplate() {
    return FlintBox(
      padding: EdgeInsets.zero(),
      margin: EdgeInsets.zero(),
      children: [
        // Hero Section
        _buildHeroSection(),

        // Features Section
        _buildFeaturesSection(),

        // Getting Started Section
        _buildGettingStartedSection(),

        // Community Section
        _buildCommunitySection(),

        // Footer
        _buildFooter(),
      ],
    );
  }

  FlintWidget _buildHeroSection() {
    return FlintColumn(
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      backgroundColor: FlintColors.primary,
      alignment: Alignment.center,
      gap: 10,
      children: [
        FlintText(
          '🚀 Flint Dart',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: FlintColors.white,
          ),
          align: TextAlign.center,
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 16),
          children: [
            FlintText(
              'Build beautiful emails and web applications with Dart',
              style: TextStyle(
                fontSize: 20,
                color: FlintColors.white.withOpacity(0.9),
                lineHeight: 1.5,
              ),
              align: TextAlign.center,
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 32),
          children: [
            FlintRow(
              alignment: 'center',
              gap: 16,
              children: [
                FlintButton(
                  text: 'Get Started',
                  url: '#getting-started',
                  style: ButtonStyle.primary().copyWith(
                    backgroundColor: FlintColors.white,
                    textStyle: TextStyle(
                      color: FlintColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  borderRadius: BorderRadius.circular(8),
                ),
                FlintButton(
                  text: 'View Documentation',
                  url: 'https://flintdart.eulogia.net',
                  style: ButtonStyle.outline().copyWith(
                    textStyle: TextStyle(
                      color: FlintColors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    border: BoxBorder.all(
                      color: FlintColors.white,
                      width: 2,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  borderRadius: BorderRadius.circular(8),
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
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      backgroundColor: FlintColors.white,
      children: [
        FlintText(
          'Why Choose Flint Dart?',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: FlintColors.gray900,
          ),
          align: TextAlign.center,
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 48),
          children: [
            FlintRow(
              columnWidths: [33, 33, 33],
              gap: 32,
              children: [
                _buildFeatureCard(
                  icon: '🎨',
                  title: 'Beautiful UI',
                  description:
                      'Create stunning email templates and web interfaces with our Flutter-inspired widget system',
                ),
                _buildFeatureCard(
                  icon: '📧',
                  title: 'Email First',
                  description:
                      'Optimized for email clients with fallbacks for maximum compatibility across all platforms',
                ),
                _buildFeatureCard(
                  icon: '⚡',
                  title: 'Fast Development',
                  description:
                      'Hot reload, type safety, and Dart\'s excellent tooling for rapid development',
                ),
              ],
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 48),
          children: [
            FlintRow(
              columnWidths: [33, 33, 33],
              gap: 32,
              children: [
                _buildFeatureCard(
                  icon: '🔧',
                  title: 'Full Stack',
                  description:
                      'Build everything from backend APIs to frontend UIs with a single codebase',
                ),
                _buildFeatureCard(
                  icon: '📱',
                  title: 'Responsive',
                  description:
                      'Automatic responsive design that works perfectly on desktop, tablet, and mobile',
                ),
                _buildFeatureCard(
                  icon: '🎯',
                  title: 'Developer Friendly',
                  description:
                      'Comprehensive documentation, examples, and a growing community',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildFeatureCard({
    required String icon,
    required String title,
    required String description,
  }) {
    return FlintBox(
      padding: EdgeInsets.all(24),
      margin: EdgeInsets.all(24),
      backgroundColor: FlintColors.gray50,
      borderRadius: BorderRadius.circular(12),
      alignment: BoxAlignment.center,
      children: [
        FlintText(
          icon,
          style: TextStyle(fontSize: 48),
          align: TextAlign.center,
        ),
        FlintColumn(
          children: [
            FlintText(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: FlintColors.gray900,
              ),
              align: TextAlign.center,
            ),
            FlintText(
              description,
              style: TextStyle(
                fontSize: 14,
                color: FlintColors.gray600,
                lineHeight: 1.6,
              ),
              align: TextAlign.start,
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildGettingStartedSection() {
    return FlintBox(
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      backgroundColor: FlintColors.gray100,
      children: [
        FlintText(
          'Get Started in Minutes',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: FlintColors.gray900,
          ),
          align: TextAlign.center,
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 48),
          children: [
            FlintRow(
              columnWidths: [50, 50],
              gap: 48,
              children: [
                _buildStepCard(
                  step: '1',
                  title: 'Install Flint Dart',
                  description:
                      'Add Flint Dart to your pubspec.yaml and start building',
                  code: 'dart pub add flint_dart',
                ),
                _buildStepCard(
                  step: '2',
                  title: 'Create Your First Template',
                  description:
                      'Use our widget system to build beautiful emails',
                  code: 'flint make:mail welcome',
                ),
              ],
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 32),
          children: [
            FlintRow(
              columnWidths: [50, 50],
              gap: 48,
              children: [
                _buildStepCard(
                  step: '3',
                  title: 'Preview Instantly',
                  description:
                      'Use our built-in preview server to see your templates',
                  code: 'flint preview',
                ),
                _buildStepCard(
                  step: '4',
                  title: 'Deploy & Send',
                  description:
                      'Integrate with your email service and start sending',
                  code: 'await welcomeMail.send();',
                ),
              ],
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 48),
          children: [
            FlintButton(
              text: 'Read Full Documentation',
              url: 'https://flintdart.eulogia.net',
              style: ButtonStyle.primary().copyWith(
                backgroundColor: FlintColors.primary,
                textStyle: TextStyle(
                  color: FlintColors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              borderRadius: BorderRadius.circular(8),
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildStepCard({
    required String step,
    required String title,
    required String description,
    required String code,
  }) {
    return FlintBox(
      padding: EdgeInsets.all(24),
      backgroundColor: FlintColors.white,
      borderRadius: BorderRadius.circular(12),
      border: BoxBorder.all(color: FlintColors.gray300),
      children: [
        FlintBox(
          padding: EdgeInsets.all(12),
          backgroundColor: FlintColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          alignment: BoxAlignment.center,
          constraints: BoxConstraints.tightFor(width: 40, height: 40),
          children: [
            FlintText(
              step,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: FlintColors.primary,
              ),
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 16),
          children: [
            FlintText(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: FlintColors.gray900,
              ),
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 8),
          children: [
            FlintText(
              description,
              style: TextStyle(
                fontSize: 14,
                color: FlintColors.gray600,
                lineHeight: 1.5,
              ),
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 16),
          padding: EdgeInsets.all(12),
          backgroundColor: FlintColors.gray900,
          borderRadius: BorderRadius.circular(6),
          children: [
            FlintText(
              code,
              style: TextStyle(
                fontSize: 14,
                color: FlintColors.gray100,
                fontFamily: 'Monaco, Menlo, "Ubuntu Mono", monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildCommunitySection() {
    return FlintColumn(
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      backgroundColor: FlintColors.white,
      alignment: Alignment.center,
      children: [
        FlintText(
          'Join Our Community',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: FlintColors.gray900,
          ),
          align: TextAlign.center,
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 16),
          children: [
            FlintText(
              'Flint Dart is open source and built by developers for developers',
              style: TextStyle(
                fontSize: 18,
                color: FlintColors.gray600,
              ),
              align: TextAlign.center,
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 48),
          children: [
            FlintRow(
              alignment: 'center',
              gap: 24,
              children: [
                _buildCommunityLink(
                  icon: '🐙',
                  platform: 'GitHub',
                  url: 'https://github.com/flint-dart/flint',
                ),
                _buildCommunityLink(
                  icon: '💬',
                  platform: 'Discord',
                  url: 'https://discord.gg/flint-dart',
                ),
                _buildCommunityLink(
                  icon: '📚',
                  platform: 'Documentation',
                  url: 'https://flintdart.eulogia.net',
                ),
                _buildCommunityLink(
                  icon: '🐦',
                  platform: 'Twitter',
                  url: 'https://twitter.com/flint_dart',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildCommunityLink({
    required String icon,
    required String platform,
    required String url,
  }) {
    return FlintButton(
      text: '$icon $platform',
      url: url,
      style: ButtonStyle.outline().copyWith(
        textStyle: TextStyle(
          color: FlintColors.gray700,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        border: BoxBorder.all(
          color: FlintColors.gray300,
          width: 1,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      borderRadius: BorderRadius.circular(6),
    );
  }

  FlintWidget _buildFooter() {
    return FlintColumn(
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      backgroundColor: FlintColors.gray900,
      alignment: Alignment.center,
      children: [
        FlintText(
          '🚀 Flint Dart',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: FlintColors.white,
          ),
          align: TextAlign.center,
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 16),
          children: [
            FlintText(
              'Build beautiful applications with Dart',
              style: TextStyle(
                fontSize: 14,
                color: FlintColors.gray400,
              ),
              align: TextAlign.center,
            ),
          ],
        ),
        FlintBox(
          margin: EdgeInsets.only(top: 24),
          children: [
            FlintRow(
              alignment: 'center',
              gap: 24,
              children: [
                FlintRichText(
                  children: [
                    FlintTextSpan(
                      '© ${DateTime.now().year} Flint Dart',
                      style: TextStyle(color: FlintColors.gray400),
                    ),
                  ],
                ),
                FlintRichText(
                  children: [
                    FlintTextSpan(
                      'MIT License',
                      style: TextStyle(color: FlintColors.gray400),
                      onTap:
                          'https://github.com/flint-dart/flint/blob/main/LICENSE',
                    ),
                  ],
                ),
                FlintRichText(
                  children: [
                    FlintTextSpan(
                      'Privacy',
                      style: TextStyle(color: FlintColors.gray400),
                      onTap: 'https://flintdart.eulogia.net/privacy',
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
