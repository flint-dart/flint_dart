import 'package:flint_dart/flint_ui_server.dart';
import 'package:test/test.dart';

void main() {
  group('FlintServerRenderer', () {
    test('renders text, elements, attributes, and styles safely', () {
      final html = const FlintServerRenderer().render(
        h(
          'section',
          props: {
            'className': 'hero',
            'style': {'color': 'red', 'font-weight': 700},
            'data-title': 'A "quote"',
            'onClick': (_) {},
          },
          children: [
            h('h1', children: ['Hello <Flint>']),
            input(props: {'disabled': true, 'value': 'Ready'}),
          ],
        ),
      );

      expect(
        html,
        '<section class="hero" style="color: red; font-weight: 700" '
        'data-title="A &quot;quote&quot;"><h1>Hello &lt;Flint&gt;</h1>'
        '<input disabled value="Ready"></section>',
      );
      expect(html, isNot(contains('onClick')));
    });

    test('renders registered page components', () {
      final registry = FlintComponentRegistry({
        'Home': (props) => _GreetingPage(props['name']?.toString() ?? ''),
      });

      final html = const FlintServerRenderer().renderPage(
        registry,
        'Home',
        props: {'name': 'Ada'},
      );

      expect(html, '<main><p>Hello Ada</p></main>');
    });

    test('renders scoped styles before HTML', () {
      final html = const FlintServerRenderer().render(
        div(
          props: {
            'className': 'flint-s-test',
            '_flintStyleCss': '.flint-s-test:hover { color: red; }',
          },
          children: ['Hover'],
        ),
      );

      expect(html, startsWith('<style data-flint-ssr-style>'));
      expect(html, contains('.flint-s-test:hover { color: red; }'));
      expect(html, endsWith('<div class="flint-s-test">Hover</div>'));
    });

    test('renders media and location pages without browser API access', () {
      final registry = FlintComponentRegistry({
        'DeviceCheck': (_) => _DeviceCheckPage(),
      });

      final html = const FlintServerRenderer().renderPage(
        registry,
        'DeviceCheck',
      );

      expect(html, contains('<h1>Device check</h1>'));
      expect(html, contains('Use camera'));
      expect(html, contains('Use microphone'));
      expect(html, contains('Share screen'));
      expect(html, contains('Use location'));
      expect(html, contains('<video'));
      expect(html, contains('id="device-preview"'));
      expect(html, contains('<canvas'));
      expect(html, contains('id="drawing-board"'));
      expect(html, contains('id="three-preview"'));
      expect(html, isNot(contains('_flintMediaController')));
      expect(html, isNot(contains('_flintCanvasController')));
      expect(html, isNot(contains('_flintThreeSceneController')));
      expect(html, isNot(contains('onClick')));
    });
  });
}

class _GreetingPage extends StatelessComponent {
  _GreetingPage(this.name);

  final String name;

  @override
  View build() {
    return h(
      'main',
      children: [
        h('p', children: ['Hello $name']),
      ],
    );
  }
}

class _DeviceCheckPage extends StatelessComponent {
  @override
  View build() {
    const media = MediaDevicesController();
    const location = GeoLocationController();

    return h(
      'main',
      children: [
        h('h1', children: ['Device check']),
        h(
          'p',
          children: [
            media.isSupported || location.isSupported
                ? 'Device APIs are available.'
                : 'Device APIs activate in the browser.',
          ],
        ),
        button(
          props: {'onClick': (_) => media.requestCamera()},
          children: ['Use camera'],
        ),
        button(
          props: {'onClick': (_) => media.requestMicrophone()},
          children: ['Use microphone'],
        ),
        button(
          props: {'onClick': (_) => media.requestScreenShare()},
          children: ['Share screen'],
        ),
        button(
          props: {'onClick': (_) => location.currentPosition()},
          children: ['Use location'],
        ),
        MediaPreview(
          id: 'device-preview',
          result: const MediaStreamResult(granted: false),
          fallback: 'Preview appears after permission is granted.',
        ),
        Canvas(
          controller: CanvasController(),
          width: 320,
          height: 180,
          props: const {'id': 'drawing-board'},
        ),
        ThreeScene(
          controller: ThreeSceneController(),
          width: 320,
          height: 180,
          props: const {'id': 'three-preview'},
        ),
      ],
    );
  }
}
