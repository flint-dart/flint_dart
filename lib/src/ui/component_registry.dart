import 'component.dart';

/// Builds a page component from server-provided props.
typedef FlintPageBuilder = FlintComponent Function(Map<String, dynamic> props);

/// Registry that maps Flint page names to component builders.
class PageRegistry {
  final Map<String, FlintPageBuilder> _pages = {};

  /// Creates a registry with optional initial [pages].
  PageRegistry([Map<String, FlintPageBuilder>? pages]) {
    if (pages != null) registerAll(pages);
  }

  /// Registered page builders keyed by page name.
  Map<String, FlintPageBuilder> get pages => Map.unmodifiable(_pages);

  /// Registers a page [builder] for [name].
  void register(String name, FlintPageBuilder builder) {
    _pages[name] = builder;
  }

  /// Registers all page builders from [pages].
  void registerAll(Map<String, FlintPageBuilder> pages) {
    _pages.addAll(pages);
  }

  /// Returns the page builder registered for [name].
  FlintPageBuilder? operator [](String name) => _pages[name];

  /// Returns a registry containing only the requested [names].
  ///
  /// This is useful for page-level bundles where the generated browser
  /// entrypoint should only retain the page component it is responsible for.
  PageRegistry only(Iterable<String> names) {
    final selected = <String, FlintPageBuilder>{};
    for (final name in names) {
      final builder = _pages[name];
      if (builder != null) selected[name] = builder;
    }
    return PageRegistry(selected);
  }
}

/// Registry that maps Flint page names to component builders.
@Deprecated('Use PageRegistry instead')
class FlintComponentRegistry extends PageRegistry {
  /// Creates a registry with optional initial [pages].
  FlintComponentRegistry([Map<String, FlintPageBuilder>? pages]) : super(pages);

  @override
  FlintComponentRegistry only(Iterable<String> names) {
    final selected = <String, FlintPageBuilder>{};
    for (final name in names) {
      final builder = pages[name];
      if (builder != null) selected[name] = builder;
    }
    return FlintComponentRegistry(selected);
  }
}
