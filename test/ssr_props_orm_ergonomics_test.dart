import 'package:flint_dart/flint_ui_server.dart';
import 'package:flint_dart/src/database/model/model.dart';
import 'package:flint_dart/schema.dart' as schema;
import 'package:test/test.dart';

class _GreetingProps implements FlintProps {
  final String name;
  final int count;

  const _GreetingProps({required this.name, this.count = 0});

  factory _GreetingProps.fromJson(Map<String, dynamic> json) {
    return _GreetingProps(
      name: json['name']?.toString() ?? 'Guest',
      count: int.tryParse(json['count']?.toString() ?? '0') ?? 0,
    );
  }

  @override
  Map<String, dynamic> toJson() => {'name': name, 'count': count};
}

class _SafeSsrPage extends TypedStatefulComponent<_GreetingProps> {
  static final route = FlintPageRoute<_GreetingProps>(
    name: 'SafeSsr',
    fromJson: _GreetingProps.fromJson,
    builder: _SafeSsrPage.new,
  );

  _SafeSsrPage(super.props);

  late String message;
  bool didMountCalled = false;

  @override
  void initProps() {
    message = 'Hello, ${props.name} (${props.count})';
  }

  @override
  void didMount() {
    didMountCalled = true;
  }

  @override
  View build() {
    return div(children: [text(message)]);
  }
}

class _DirectTypedStateful extends StatefulComponent<_GreetingProps> {
  _DirectTypedStateful(super.props);

  late String label;

  @override
  void initProps() {
    label = 'Stateful:${props.name}:${props.count}';
  }

  @override
  View build() => span(children: [text(label)]);
}

class _DirectTypedStateless extends StatelessComponent<_GreetingProps> {
  _DirectTypedStateless(super.props);

  @override
  View build() => span(children: [text('Stateless:${props.name}:${props.count}')]);
}

class _BrokenLateDidMountComponent extends StatefulComponent {
  late String uninitializedInSsr;

  @override
  void didMount() {
    uninitializedInSsr = 'Browser Only';
  }

  @override
  View build() {
    return div(children: [text(uninitializedInSsr)]);
  }
}

class _FluentPostModel extends Model<_FluentPostModel> {
  _FluentPostModel() : super(_FluentPostModel.new);

  @override
  String get tableName => 'blog_posts';

  @override
  void schema() {
    string('title', length: 255);
    string('slug', isUnique: true);
    this.text('content');
    jsonCol('tagIds', isNullable: true);
    string('status', defaultValue: 'draft');
    integer('views', defaultValue: 0);
  }

  String get title => getAttribute('title') ?? '';
  set title(String val) => setAttribute('title', val);

  String get slug => getAttribute('slug') ?? '';
  set slug(String val) => setAttribute('slug', val);

  String get status => getAttribute('status') ?? 'draft';
  set status(String val) => setAttribute('status', val);

  int get views => getAttribute('views') ?? 0;
  set views(int val) => setAttribute('views', val);
}

class _DuplicateTableRegistry extends schema.TableRegistry {
  const _DuplicateTableRegistry();

  @override
  List<schema.Table> get tables => [
        _FluentPostModel().table,
        _FluentPostModel().table,
      ];
}

void main() {
  group('SSR Lifecycle Guardrails', () {
    test('runs initProps() and initState() before build() during SSR', () {
      final page = _SafeSsrPage(const _GreetingProps(name: 'Ada', count: 3));
      const renderer = FlintServerRenderer(includeScopedStyles: false);

      final html = renderer.render(page);

      expect(html, equals('<div>Hello, Ada (3)</div>'));
      expect(page.isInitialized, isTrue);
      expect(page.didMountCalled, isFalse);
      expect(page.isServer, isTrue);
    });

    test('wraps LateInitializationError in build() with actionable SSR message',
        () {
      const renderer = FlintServerRenderer(includeScopedStyles: false);

      expect(
        () => renderer.render(_BrokenLateDidMountComponent()),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('[Flint SSR] LateInitializationError'),
              contains('initProps()'),
              contains('initState()'),
            ),
          ),
        ),
      );
    });
  });

  group('Typed Props & PageRegistry', () {
    test('registers FlintPageRoute and renders with typed props', () {
      final registry = PageRegistry()..registerRoute(_SafeSsrPage.route);
      const renderer = FlintServerRenderer(includeScopedStyles: false);

      final htmlFromMap = renderer.renderPage(
        registry,
        'SafeSsr',
        props: {'name': 'Grace', 'count': 7},
      );
      expect(htmlFromMap, equals('<div>Hello, Grace (7)</div>'));

      final htmlFromTyped = renderer.renderPage(
        registry,
        'SafeSsr',
        props: const _GreetingProps(name: 'Linus', count: 42),
      );
      expect(htmlFromTyped, equals('<div>Hello, Linus (42)</div>'));

      final htmlFromRoute = renderer.renderPageRoute(
        _SafeSsrPage.route,
        const _GreetingProps(name: 'Margaret', count: 99),
      );
      expect(htmlFromRoute, equals('<div>Hello, Margaret (99)</div>'));

      final stateful = _DirectTypedStateful(
        const _GreetingProps(name: 'Katherine', count: 11),
      );
      expect(
        renderer.render(stateful),
        equals('<span>Stateful:Katherine:11</span>'),
      );

      final nextStateful = _DirectTypedStateful(
        const _GreetingProps(name: 'Hamilton', count: 22),
      );
      stateful.updateFrom(nextStateful);
      expect(stateful.props.name, equals('Hamilton'));
      expect(stateful.props.count, equals(22));

      final stateless = _DirectTypedStateless(
        const _GreetingProps(name: 'Turing', count: 77),
      );
      expect(
        renderer.render(stateless),
        equals('<span>Stateless:Turing:77</span>'),
      );
    });
  });

  group('ORM Ergonomics & Fluent Schema Builder', () {
    test('exposes query builder methods directly on Model<T>', () {
      // Notice: model_query.dart is NOT imported in this test file!
      final model = _FluentPostModel()
        ..title = 'Flint 1.5 Release'
        ..views = 120;

      expect(model.title, equals('Flint 1.5 Release'));
      expect(model.status, equals('draft'));
      expect(model.views, equals(120));
      expect(model.table.name, equals('blog_posts'));
      expect(model.table.columns.length,
          equals(7)); // auto-prepended id + 6 schema columns
      expect(model.primaryKey, equals('id'));

      model
          .where('status', 'published')
          .whereIn('views', [10, 20, 120])
          .orderBy('views', desc: true)
          .limit(5);

      final whereSql = model.qb.compileWhereSql();
      expect(whereSql, contains('WHERE status ='));
      expect(whereSql, contains('views IN'));
      expect(model.qb.whereParams.values, contains('published'));
      expect(model.qb.whereParams.values, containsAll([10, 20, 120]));
    });

    test(
        'auto-constructs Table from fluent schema() builder without code generation',
        () {
      final post = _FluentPostModel()
        ..title = 'Fluent Flint Dart'
        ..slug = 'fluent-flint-dart';

      expect(post.title, equals('Fluent Flint Dart'));
      expect(post.slug, equals('fluent-flint-dart'));
      expect(post.table.name, equals('blog_posts'));
      // Auto-prepended id + 6 columns defined in schema()
      expect(post.table.columns.length, equals(7));
      final colNames = post.table.columns.map((c) => c.name).toList();
      expect(
          colNames,
          equals(
              ['id', 'title', 'slug', 'content', 'tagIds', 'status', 'views']));
      expect(post.primaryKey, equals('id'));
    });

    test('deduplicates tables in TableRegistry.uniqueTables', () {
      const registry = _DuplicateTableRegistry();
      expect(registry.tables.length, equals(2));
      expect(registry.uniqueTables.length, equals(1));
      expect(registry.uniqueTables.first.name, equals('blog_posts'));
    });
  });
}
