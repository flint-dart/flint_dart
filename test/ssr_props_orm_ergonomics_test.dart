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

class _ArticleModel extends Model<_ArticleModel> {
  _ArticleModel() : super(_ArticleModel.new);

  static const colTitle = schema.ColumnField<String>(
    'title',
    type: schema.ColumnType.string,
    length: 200,
  );
  static const colStatus = schema.ColumnField<String>(
    'status',
    type: schema.ColumnType.string,
    defaultValue: 'draft',
  );
  static const colViews = schema.ColumnField<int>(
    'views',
    type: schema.ColumnType.integer,
    defaultValue: 0,
  );

  String get title => getField(colTitle) ?? '';
  set title(String value) => setField(colTitle, value);

  String get status => getField(colStatus) ?? 'draft';
  set status(String value) => setField(colStatus, value);

  int get views => getField(colViews) ?? 0;
  set views(int value) => setField(colViews, value);

  @override
  String get tableName => 'articles';

  @override
  List<schema.ColumnField> get fields => [colTitle, colStatus, colViews];
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
    json('tagIds', isNullable: true);
    string('status', defaultValue: 'draft');
  }

  String get title => getAttribute('title') ?? '';
  set title(String val) => setAttribute('title', val);

  String get slug => getAttribute('slug') ?? '';
  set slug(String val) => setAttribute('slug', val);
}

class _DuplicateTableRegistry extends schema.TableRegistry {
  const _DuplicateTableRegistry();

  @override
  List<schema.Table> get tables => [
        _ArticleModel().table,
        _ArticleModel().table,
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

    test('wraps LateInitializationError in build() with actionable SSR message', () {
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
    });
  });

  group('ORM Ergonomics & ColumnField Constants', () {
    test('exposes query builder and ColumnField methods directly on Model<T>', () {
      // Notice: model_query.dart is NOT imported in this test file!
      final model = _ArticleModel()
        ..title = 'Flint 1.5 Release'
        ..views = 120;

      expect(model.title, equals('Flint 1.5 Release'));
      expect(model.status, equals('draft'));
      expect(model.views, equals(120));
      expect(model.table.name, equals('articles'));
      expect(model.table.columns.length, equals(4)); // auto-prepended id + 3 fields
      expect(model.primaryKey, equals('id'));

      model
          .whereField(_ArticleModel.colStatus, 'published')
          .whereInField(_ArticleModel.colViews, [10, 20, 120])
          .orderByField(_ArticleModel.colViews, desc: true)
          .limit(5);

      final whereSql = model.qb.compileWhereSql();
      expect(whereSql, contains('WHERE status ='));
      expect(whereSql, contains('views IN'));
      expect(model.qb.whereParams.values, contains('published'));
      expect(model.qb.whereParams.values, containsAll([10, 20, 120]));
    });

    test('auto-constructs Table from fluent schema() builder without code generation', () {
      final post = _FluentPostModel()
        ..title = 'Fluent Flint Dart'
        ..slug = 'fluent-flint-dart';

      expect(post.title, equals('Fluent Flint Dart'));
      expect(post.slug, equals('fluent-flint-dart'));
      expect(post.table.name, equals('blog_posts'));
      // Auto-prepended id + 5 columns defined in schema()
      expect(post.table.columns.length, equals(6));
      final colNames = post.table.columns.map((c) => c.name).toList();
      expect(colNames, equals(['id', 'title', 'slug', 'content', 'tagIds', 'status']));
      expect(post.primaryKey, equals('id'));
    });

    test('deduplicates tables in TableRegistry.uniqueTables', () {
      const registry = _DuplicateTableRegistry();
      expect(registry.tables.length, equals(2));
      expect(registry.uniqueTables.length, equals(1));
      expect(registry.uniqueTables.first.name, equals('articles'));
    });
  });
}
