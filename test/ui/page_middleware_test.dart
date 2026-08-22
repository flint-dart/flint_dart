@TestOn('browser')
library;

import 'dart:convert';

import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';
import 'package:universal_web/web.dart' as web;

class _MiddlewareTestPage extends StatefulComponent {
  _MiddlewareTestPage(this.props);

  final Map<String, dynamic> props;

  @override
  FlintNode build() {
    return Text(props['message']?.toString() ?? 'rendered');
  }
}

void main() {
  group('createFlintApp middleware', () {
    late web.Element host;

    setUp(() {
      host = web.document.createElement('div');
      host.id = 'middleware-test-root';
      web.document.body?.appendChild(host);
    });

    tearDown(() {
      host.remove();
    });

    test('can stop rendering before the page mounts', () async {
      host.setAttribute(
        'data-flint-page',
        jsonEncode({
          'component': 'MiddlewareTest',
          'props': {'message': 'should not render'},
        }),
      );

      createFlintApp(
        '#middleware-test-root',
        pages: {'MiddlewareTest': _MiddlewareTestPage.new},
        middlewares: [
          (context) {
            context.stop();
          },
        ],
      );

      await Future<void>.delayed(Duration.zero);

      expect(host.textContent, isEmpty);
    });

    test('renders when middleware allows the page', () async {
      host.setAttribute(
        'data-flint-page',
        jsonEncode({
          'component': 'MiddlewareTest',
          'props': {'message': 'allowed'},
        }),
      );

      createFlintApp(
        '#middleware-test-root',
        pages: {'MiddlewareTest': _MiddlewareTestPage.new},
        middlewares: [(_) {}],
      );

      await Future<void>.delayed(Duration.zero);

      expect(host.textContent, 'allowed');
    });
  });
}
