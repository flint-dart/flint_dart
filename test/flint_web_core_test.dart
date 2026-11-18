@TestOn('browser')
library;

import 'package:flint_dart/flint_web_core.dart';
import 'package:test/test.dart';

void main() {
  group('Flint Web UI core', () {
    test('normalizes text children into FlintText nodes', () {
      final node = h('h1', children: ['Hello']);

      expect(node.tag, 'h1');
      expect(node.children, hasLength(1));
      expect(node.children.single, isA<FlintText>());
      expect((node.children.single as FlintText).value, 'Hello');
    });

    test('wraps components in component nodes', () {
      final node = component(_Counter());

      expect(node.component, isA<_Counter>());
    });

    test('setState updates local fields and schedules a render', () {
      var renders = 0;
      final counter = _Counter()..attach(() => renders++);

      counter.increment();

      expect(counter.count, 1);
      expect(renders, 1);
    });

    test('Flutter-style widgets build element nodes', () {
      final node = Column(
        children: [
          Text('Hello'),
          Button(child: Text('Tap')),
        ],
      );

      expect(node.tag, 'div');
      expect(node.props['style'], containsPair('display', 'flex'));
      expect(node.children.first, isA<Text>());
      expect(node.children.last, isA<Button>());
    });

    test('Head stores document title and browser head tags', () {
      final head = Head(
        title: 'Dashboard',
        tags: [
          Head.script(src: 'https://cdn.tailwindcss.com'),
          Head.link(href: 'style.css'),
        ],
      );

      expect(head.title, 'Dashboard');
      expect(head.tags, hasLength(2));
      expect(head.tags.first.tag, 'script');
      expect(head.tags.first.props['src'], 'https://cdn.tailwindcss.com');
      expect(head.tags.last.tag, 'link');
      expect(head.tags.last.props['href'], 'style.css');
    });
  });
}

class _Counter extends FlintComponent {
  int count = 0;

  void increment() {
    setState(() => count++);
  }

  @override
  FlintNode build() => text(count);
}
