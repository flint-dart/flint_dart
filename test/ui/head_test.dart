@TestOn('browser')
library;

import 'package:flint_dart/flint_ui.dart';
import 'package:test/test.dart';
import 'package:universal_web/web.dart' as web;

void main() {
  group('Head', () {
    late String previousTitle;

    setUp(() {
      previousTitle = web.document.title;
      _removeFlintHeadTags();
      _removeSeoTag('meta', 'name', 'description');
      _removeSeoTag('meta', 'property', 'og:title');
      _removeSeoTag('meta', 'property', 'og:description');
      _removeSeoTag('meta', 'property', 'og:url');
      _removeSeoTag('meta', 'property', 'og:image');
      _removeSeoTag('meta', 'property', 'og:type');
      _removeSeoTag('link', 'rel', 'canonical');
    });

    tearDown(() {
      web.document.title = previousTitle;
      _removeFlintHeadTags();
      _removeSeoTag('meta', 'name', 'description');
      _removeSeoTag('meta', 'property', 'og:title');
      _removeSeoTag('meta', 'property', 'og:description');
      _removeSeoTag('meta', 'property', 'og:url');
      _removeSeoTag('meta', 'property', 'og:image');
      _removeSeoTag('meta', 'property', 'og:type');
      _removeSeoTag('link', 'rel', 'canonical');
    });

    test('updates title and common SEO tags from Dart', () {
      Head.seo(
        title: 'Flint UI',
        description: 'Dart-first UI for Flint apps.',
        canonical: 'https://flint.dev/ui',
        image: 'https://flint.dev/og.png',
      ).didMount();

      expect(web.document.title, 'Flint UI');
      expect(
        _metaContent('name', 'description'),
        'Dart-first UI for Flint apps.',
      );
      expect(_metaContent('property', 'og:title'), 'Flint UI');
      expect(
        _metaContent('property', 'og:description'),
        'Dart-first UI for Flint apps.',
      );
      expect(_metaContent('property', 'og:url'), 'https://flint.dev/ui');
      expect(_metaContent('property', 'og:image'), 'https://flint.dev/og.png');
      expect(_metaContent('property', 'og:type'), 'website');
      expect(_canonicalHref(), 'https://flint.dev/ui');
    });

    test(
      'reuses existing server-rendered meta tags instead of duplicating',
      () {
        final serverDescription = web.document.createElement('meta');
        serverDescription.setAttribute('name', 'description');
        serverDescription.setAttribute('content', 'Server description');
        web.document.head?.appendChild(serverDescription);

        Head(
          title: 'Client title',
          description: 'Client description',
        ).didMount();

        final descriptions = web.document.querySelectorAll(
          'meta[name="description"]',
        );
        expect(descriptions.length, 1);
        expect(_metaContent('name', 'description'), 'Client description');
        expect(web.document.title, 'Client title');
      },
    );

    test('updates existing Flint head tags by stable key', () {
      final head = Head(
        tags: [Head.meta(name: 'robots', content: 'index,follow')],
      );

      head.didMount();
      Head(
        tags: [Head.meta(name: 'robots', content: 'noindex')],
      ).didMount();

      final robots = web.document.querySelectorAll('meta[name="robots"]');
      expect(robots.length, 1);
      expect(_metaContent('name', 'robots'), 'noindex');
    });
  });
}

String? _metaContent(String attr, String value) {
  return web.document
      .querySelector('meta[$attr="$value"]')
      ?.getAttribute('content');
}

String? _canonicalHref() {
  return web.document
      .querySelector('link[rel="canonical"]')
      ?.getAttribute('href');
}

void _removeFlintHeadTags() {
  final elements = _elements('[data-flint-head]');
  for (final element in elements) {
    element.remove();
  }
}

void _removeSeoTag(String tag, String attr, String value) {
  final elements = _elements('$tag[$attr="$value"]');
  for (final element in elements) {
    element.remove();
  }
}

List<web.Element> _elements(String selector) {
  final nodes = web.document.querySelectorAll(selector);
  return [
    for (var i = 0; i < nodes.length; i++)
      if (nodes.item(i) case final web.Element element) element,
  ];
}
