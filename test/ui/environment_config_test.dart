@TestOn('browser')
library;

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';
import 'package:universal_web/web.dart' as web;

void main() {
  group('EnvironmentConfig', () {
    final metaElements = <web.Element>[];

    tearDown(() {
      for (final element in metaElements) {
        element.remove();
      }
      metaElements.clear();
      globalContext.delete('__FLINT_ENV__'.toJS);
      globalContext.delete('flintEnv'.toJS);
    });

    test('reads explicit values before fallback', () {
      final config = const EnvironmentConfig({'API_URL': '/api'});

      expect(config.get('API_URL', fallback: '/fallback'), '/api');
      expect(config.get('MISSING', fallback: '/fallback'), '/fallback');
    });

    test('reads meta tag values', () {
      _addMeta(metaElements, 'flint-env:API_URL', '/meta-api');

      expect(env.get('API_URL'), '/meta-api');
    });

    test('reads browser global values', () {
      globalContext.setProperty(
        '__FLINT_ENV__'.toJS,
        {'API_URL': '/global-api'}.jsify(),
      );

      expect(env.get('API_URL'), '/global-api');
    });

    test('parses bool, int, and double values', () {
      final config = const EnvironmentConfig({
        'DEBUG': 'true',
        'PORT': '3000',
        'RATIO': '1.5',
      });

      expect(config.getBool('DEBUG'), isTrue);
      expect(config.getInt('PORT'), 3000);
      expect(config.getDouble('RATIO'), 1.5);
    });

    test('merges values into a new config', () {
      final config = const EnvironmentConfig({
        'API_URL': '/api',
      }).merge({'API_URL': '/v2', 'APP_NAME': 'Flint'});

      expect(config.get('API_URL'), '/v2');
      expect(config.get('APP_NAME'), 'Flint');
    });
  });
}

void _addMeta(List<web.Element> elements, String name, String content) {
  final element = web.document.createElement('meta');
  element.setAttribute('name', name);
  element.setAttribute('content', content);
  web.document.head?.appendChild(element);
  elements.add(element);
}
