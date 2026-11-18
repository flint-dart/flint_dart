import 'package:flint_dart/ui.dart';

class WelcomePage extends FlintComponent {
  final Map<String, dynamic> props;

  WelcomePage(this.props);

  @override
  FlintNode build() {
    final features = _features();
    final version = props['version']?.toString() ?? 'dev';
    final tagline = props['tagline']?.toString() ??
        'Build backend routes and browser UI with Dart.';

    return Container(
      props: {'className': 'welcome-page'},
      children: [
        h('header', props: {
          'className': 'topbar'
        }, children: [
          Row(
            props: {'className': 'brand'},
            children: [
              Container(props: {'className': 'brand-mark'}, child: Text('F')),
              Text('Flint Dart'),
            ],
          ),
          Row(
            props: {'className': 'nav-actions'},
            children: [
              h('a', props: {'href': '/docs'}, children: ['Docs']),
              h('a', props: {'href': '/guide'}, children: ['Guide']),
              h('a', props: {'href': '/swagger'}, children: ['API']),
              h('a', props: {'href': '/preview/email'}, children: ['Email']),
            ],
          ),
        ]),
        h('section', props: {
          'className': 'hero'
        }, children: [
          Column(
            props: {'className': 'hero-copy'},
            children: [
              Container(
                props: {'className': 'eyebrow'},
                child: Text('Flint UI bridge - v$version'),
              ),
              h('h1', children: ['Welcome to Flint Dart']),
              h('p', props: {'className': 'hero-text'}, children: [tagline]),
              Row(
                props: {'className': 'hero-actions'},
                children: [
                  h('a',
                      props: {'className': 'primary-link', 'href': '#start'},
                      children: ['Get started']),
                  h('a',
                      props: {'className': 'secondary-link', 'href': '/docs'},
                      children: ['View docs']),
                  h('a',
                      props: {'className': 'secondary-link', 'href': '/guide'},
                      children: ['Open guide']),
                ],
              ),
            ],
          ),
          Container(
            props: {'className': 'code-panel'},
            children: [
              Text('app.get("/", (ctx) {'),
              Text('  return ctx.res.page("Welcome", props: data);'),
              Text('});'),
              Text(''),
              Text('createFlintApp("#app", registry: componentRegistry);'),
            ],
          ),
        ]),
        h('section', props: {
          'className': 'feature-grid'
        }, children: [
          for (final feature in features) _featureCard(feature),
        ]),
        h('section', props: {
          'className': 'start-band',
          'id': 'start'
        }, children: [
          Column(
            props: {'className': 'start-copy'},
            children: [
              h('h2', children: ['A Dart-first frontend for Flint']),
              h('p', children: [
                'Keep routes, controllers, auth, and data loading in Flint. Render browser pages from Dart components when a template is too small for the job.'
              ]),
            ],
          ),
          Container(
            props: {'className': 'command'},
            child: Text('flint run'),
          ),
        ]),
      ],
    );
  }

  List<Map<String, String>> _features() {
    final raw = props['features'];
    if (raw is List) {
      return raw.whereType<Map>().map((item) {
        return {
          'title': item['title']?.toString() ?? '',
          'body': item['body']?.toString() ?? '',
        };
      }).toList();
    }

    return const [
      {
        'title': 'Dart UI',
        'body': 'Write frontend pages with Flutter-style Flint widgets.',
      },
      {
        'title': 'Backend Bridge',
        'body': 'Return page names and props from normal Flint routes.',
      },
      {
        'title': 'One Toolchain',
        'body': 'Compile UI into web assets and serve them from Flint.',
      },
    ];
  }

  FlintNode _featureCard(Map<String, String> feature) {
    return Container(
      props: {'className': 'feature-card'},
      children: [
        h('h3', children: [feature['title'] ?? 'Feature']),
        h('p', children: [feature['body'] ?? '']),
      ],
    );
  }
}
