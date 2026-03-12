import 'package:flint_dart/flint_ui.dart';

class Welcome extends FlintTemplate {
  @override
  Head get head => Head(
        title: "Welcome to Flint Dart",
        description: "Build web apps & email templates with Dart",
        links: {"icon": "/favicon.ico"},
        styles: [
          """
          body { font-family: Arial, sans-serif; margin: 0; padding: 0; }
          """
        ],
        scripts: [
          """
          console.log("WelcomePage loaded");
          """,
        ],
      );

  @override
  List<String> styles() {
    return [];
  }

  @override
  List<String> scripts() {
    return [
      """
    console.log("Flint UI Loaded");
    """
    ];
  }

  // Create state for toggle examples
  final state = FlintState({
    "counter": 0,
    'showContent': false,
    'isDarkMode': false,
    'selectedTab': 'home',
    'items': ['Item 1', 'Item 2', 'Item 3'],
  });

  @override
  FlintWidget buildTemplate() {
    return Container(
      xData: state.toJsObject(),
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
    return Column(
      xData: """{
    counter: 0,
    showContent: false,
    isDarkMode: false,
    selectedTab: 'home',
    items: ['Item 1', 'Item 2', 'Item 3'],
  }""",
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      backgroundColor: Colors.primary,
      alignment: Alignment.center,
      gap: 20,
      children: [
        Text(
          '🚀 Flint Dart',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          align: TextAlign.center,
        ),
        Container(
          margin: EdgeInsets.only(top: 16),
          children: [
            Text(
              'Build beautiful emails and web applications with Dart',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white.withOpacity(0.9),
                lineHeight: 1.5,
              ),
              align: TextAlign.center,
            ),
          ],
        ),

        // Counter Section
        Container(
          margin: EdgeInsets.only(top: 32),
          padding: EdgeInsets.all(16),
          backgroundColor: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          children: [
            Column(
              alignment: Alignment.center,
              gap: 10,
              children: [
                Text(
                  'Counter: ${state.get('counter') ?? 0}',
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  align: TextAlign.center,
                ),
                Row(
                  alignment: 'center',
                  gap: 16,
                  children: [
                    Button(
                      text: '-',
                      onClick: () {
                        final current = state.get('counter') ?? 0;
                        state.set('counter', current - 1);
                      },
                      style: ButtonStyle.primary().copyWith(
                        backgroundColor: Colors.red,
                        textStyle: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    Button(
                      text: '+',
                      onClick: () {
                        final current = state.get('counter') ?? 0;
                        state.set('counter', current + 1);
                      },
                      xOn: {"click": "counter++"},
                      style: ButtonStyle.primary().copyWith(
                        backgroundColor: Colors.green,
                        textStyle: TextStyle(color: Colors.white, fontSize: 20),
                      ),
                      padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        // Existing Buttons
        Container(
          margin: EdgeInsets.only(top: 32),
          children: [
            Row(
              alignment: 'center',
              gap: 16,
              children: [
                Button(
                  text: 'Get Started',
                  url: '#getting-started',
                  style: ButtonStyle.primary().copyWith(
                    backgroundColor: Colors.white,
                    textStyle: TextStyle(
                      color: Colors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  borderRadius: BorderRadius.circular(8),
                ),
                Button(
                  text: 'View Documentation',
                  url: 'https://flintdart.eulogia.net',
                  style: ButtonStyle.outline().copyWith(
                    textStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                    border: BoxBorder.all(
                      color: Colors.white,
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
    return Container(
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      backgroundColor: Colors.white,
      children: [
        Text(
          'Why Choose Flint Dart?',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.gray900,
          ),
          align: TextAlign.center,
        ),
        Container(
          margin: EdgeInsets.only(top: 48),
          children: [
            Row(
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
        Container(
          margin: EdgeInsets.only(top: 48),
          children: [
            Row(
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
    return Container(
      padding: EdgeInsets.all(24),
      margin: EdgeInsets.all(24),
      backgroundColor: Colors.gray50,
      borderRadius: BorderRadius.circular(12),
      alignment: BoxAlignment.center,
      children: [
        Text(
          icon,
          style: TextStyle(fontSize: 48),
          align: TextAlign.center,
        ),
        Column(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.gray900,
              ),
              align: TextAlign.center,
            ),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.gray600,
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
    return Container(
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      backgroundColor: Colors.gray100,
      children: [
        Text(
          'Get Started in Minutes',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.gray900,
          ),
          align: TextAlign.center,
        ),
        Container(
          margin: EdgeInsets.only(top: 48),
          children: [
            Row(
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
        Container(
          margin: EdgeInsets.only(top: 32),
          children: [
            Row(
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
        Container(
          margin: EdgeInsets.only(top: 48),
          children: [
            Button(
              text: 'Read Full Documentation',
              url: 'https://flintdart.eulogia.net',
              style: ButtonStyle.primary().copyWith(
                backgroundColor: Colors.primary,
                textStyle: TextStyle(
                  color: Colors.white,
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
    return Container(
      padding: EdgeInsets.all(24),
      backgroundColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: BoxBorder.all(color: Colors.gray300),
      children: [
        Container(
          padding: EdgeInsets.all(12),
          backgroundColor: Colors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          alignment: BoxAlignment.center,
          constraints: BoxConstraints.tightFor(width: 40, height: 40),
          children: [
            Text(
              step,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.primary,
              ),
            ),
          ],
        ),
        Container(
          margin: EdgeInsets.only(top: 16),
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.gray900,
              ),
            ),
          ],
        ),
        Container(
          margin: EdgeInsets.only(top: 8),
          children: [
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.gray600,
                lineHeight: 1.5,
              ),
            ),
          ],
        ),
        Container(
          margin: EdgeInsets.only(top: 16),
          padding: EdgeInsets.all(12),
          backgroundColor: Colors.gray900,
          borderRadius: BorderRadius.circular(6),
          children: [
            Text(
              code,
              style: TextStyle(
                fontSize: 14,
                color: Colors.gray100,
                fontFamily: 'Monaco, Menlo, "Ubuntu Mono", monospace',
              ),
            ),
          ],
        ),
      ],
    );
  }

  FlintWidget _buildCommunitySection() {
    return Column(
      padding: EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      backgroundColor: Colors.white,
      alignment: Alignment.center,
      children: [
        Text(
          'Join Our Community',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.gray900,
          ),
          align: TextAlign.center,
        ),
        Container(
          margin: EdgeInsets.only(top: 16),
          children: [
            Text(
              'Flint Dart is open source and built by developers for developers',
              style: TextStyle(
                fontSize: 18,
                color: Colors.gray600,
              ),
              align: TextAlign.center,
            ),
          ],
        ),
        Container(
          margin: EdgeInsets.only(top: 48),
          children: [
            Row(
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
    return Button(
      text: '$icon $platform',
      url: url,
      style: ButtonStyle.outline().copyWith(
        textStyle: TextStyle(
          color: Colors.gray700,
          fontWeight: FontWeight.w500,
          fontSize: 14,
        ),
        border: BoxBorder.all(
          color: Colors.gray300,
          width: 1,
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      borderRadius: BorderRadius.circular(6),
    );
  }

  FlintWidget _buildFooter() {
    return Column(
      padding: EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      backgroundColor: Colors.gray900,
      alignment: Alignment.center,
      children: [
        Text(
          '🚀 Flint Dart',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          align: TextAlign.center,
        ),
        Container(
          margin: EdgeInsets.only(top: 16),
          children: [
            Text(
              'Build beautiful applications with Dart',
              style: TextStyle(
                fontSize: 14,
                color: Colors.gray400,
              ),
              align: TextAlign.center,
            ),
          ],
        ),
        Container(
          margin: EdgeInsets.only(top: 24),
          children: [
            Row(
              alignment: 'center',
              gap: 24,
              children: [
                Text(
                  '© ${DateTime.now().year} Flint Dart',
                  style: TextStyle(color: Colors.gray400),
                ),
                Text(
                  'MIT License',
                  style: TextStyle(color: Colors.gray400),
                ),
                Text(
                  'Privacy',
                  style: TextStyle(color: Colors.gray400),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
