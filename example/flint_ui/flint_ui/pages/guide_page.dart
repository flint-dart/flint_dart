import 'package:flint_ui/flint_ui.dart';

class GuidePage extends FlintComponent {
  final Map<String, dynamic> props;

  GuidePage(this.props);

  @override
  FlintNode build() {
    final title = props['title']?.toString() ?? 'Flint UI Guide';
    final intro = props['intro']?.toString() ??
        'Render Dart UI pages from backend Flint routes.';
    final steps = _steps();

    return Container(
      props: {'className': 'guide-page'},
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
              h('a', props: {'href': '/'}, children: ['Home']),
              h('a', props: {'href': '/docs'}, children: ['Docs']),
              h('a',
                  props: {'href': '/swagger.json'}, children: ['Swagger JSON']),
            ],
          ),
        ]),
        h('section', props: {
          'className': 'guide-hero'
        }, children: [
          Column(
            props: {'className': 'guide-copy'},
            children: [
              Container(
                props: {'className': 'eyebrow'},
                child: Text('Backend route - Browser UI'),
              ),
              h('h1', children: [title]),
              h('p', props: {'className': 'hero-text'}, children: [intro]),
            ],
          ),
        ]),
        h('section', props: {
          'className': 'guide-steps'
        }, children: [
          for (var i = 0; i < steps.length; i++) _stepCard(i + 1, steps[i]),
        ]),
      ],
    );
  }

  List<Map<String, String>> _steps() {
    final raw = props['steps'];
    if (raw is List) {
      return raw.whereType<Map>().map((item) {
        return {
          'label': item['label']?.toString() ?? '',
          'body': item['body']?.toString() ?? '',
          'code': item['code']?.toString() ?? '',
        };
      }).toList();
    }

    return const [];
  }

  FlintNode _stepCard(int number, Map<String, String> step) {
    return Container(
      props: {'className': 'guide-step'},
      children: [
        Container(props: {'className': 'step-number'}, child: Text(number)),
        Column(
          props: {'className': 'step-content'},
          children: [
            h('h2', children: [step['label'] ?? 'Step']),
            h('p', children: [step['body'] ?? '']),
            Container(
              props: {'className': 'command'},
              child: Text(step['code'] ?? ''),
            ),
          ],
        ),
      ],
    );
  }
}
