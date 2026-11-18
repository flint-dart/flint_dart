@TestOn('browser')
library;

import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';
import 'package:universal_web/web.dart' as web;

void main() {
  group('FlintDocument', () {
    test('exposes documentElement and root measurements', () {
      expect(flintDocument.raw, web.document);
      expect(flintDocument.documentElement, web.document.documentElement);
      expect(
        flintDocument.clientWidth,
        web.document.documentElement?.clientWidth,
      );
      expect(
        flintDocument.scrollWidth,
        web.document.documentElement?.scrollWidth,
      );
    });

    test('delegates document queries', () {
      final element = web.document.createElement('div');
      element.id = 'flint-document-test';
      web.document.body?.appendChild(element);

      expect(flintDocument.getElementById('flint-document-test'), element);
      expect(flintDocument.querySelector('#flint-document-test'), element);

      element.remove();
    });
  });
}
