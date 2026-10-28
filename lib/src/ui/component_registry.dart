import 'component.dart';

/// Builds a page component from server-provided props.
typedef FlintPageBuilder = FlintComponent Function(Map<String, dynamic> props);

/// Defines a strongly-typed page route contract shared between the server
/// (`res.pageRoute`) and the client ([PageRegistry]).
class FlintPageRoute<TProps extends FlintProps> {
  /// Registered component name used in `data-flint-page`.
  final String name;

  /// Deserializes raw JSON props into a typed [TProps] instance.
  final TProps Function(Map<String, dynamic> json) fromJson;

  /// Builds the page component from a typed [TProps] instance.
  final FlintComponent Function(TProps props) builder;

  /// Creates a strongly-typed page route definition.
  const FlintPageRoute({
    required this.name,
    required this.fromJson,
    required this.builder,
  });

  /// Converts [rawProps] into a component instance using [fromJson] and [builder].
  FlintComponent buildFromJson(Map<String, dynamic> rawProps) {
    return builder(fromJson(rawProps));
  }
}

/// Registry that maps Flint page names to component builders.
class PageRegistry {
  final Map<String, FlintPageBuilder> _pages = {};

  /// Creates a registry with optional initial [pages] and [routes].
  PageRegistry([
    Map<String, FlintPageBuilder>? pages,
    Iterable<FlintPageRoute<dynamic>>? routes,
  ]) {
    if (pages != null) registerAll(pages);
    if (routes != null) registerRoutes(routes);
  }

  /// Factory constructor to create a multi-flavor registry.
  factory PageRegistry.flavored(
    Map<String, PageRegistry> flavors, {
    String defaultFlavor,
    String? activeFlavor,
  }) = FlavoredPageRegistry;

  /// Registered page builders keyed by page name.
  Map<String, FlintPageBuilder> get pages => Map.unmodifiable(_pages);

  /// Registers a page [builder] for [name].
  void register(String name, FlintPageBuilder builder) {
    _pages[name] = builder;
  }

  /// Registers a strongly-typed page builder for [name] with automatic JSON
  /// deserialization via [fromJson].
  void registerTyped<TProps>(
    String name, {
    required TProps Function(Map<String, dynamic> json) fromJson,
    required FlintComponent Function(TProps props) builder,
  }) {
    _pages[name] = (rawProps) => builder(fromJson(rawProps));
  }

  /// Registers a shared [FlintPageRoute] definition.
  void registerRoute<TProps extends FlintProps>(FlintPageRoute<TProps> route) {
    _pages[route.name] = route.buildFromJson;
  }

  /// Registers multiple shared [FlintPageRoute] definitions.
  void registerRoutes(Iterable<FlintPageRoute<dynamic>> routes) {
    for (final route in routes) {
      _pages[route.name] = route.buildFromJson;
    }
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
  FlintComponentRegistry([super.pages]);

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


/// A multi-flavor page registry that maps flavors (e.g. 'stokash', 'farmbenefit')
/// to their respective [PageRegistry] instances, with automatic fallback to default flavor.
class FlavoredPageRegistry extends PageRegistry {
  final Map<String, PageRegistry> _flavorRegistries = {};
  String defaultFlavor;
  String? _activeFlavor;

  /// Creates a flavored registry with initial [flavors].
  FlavoredPageRegistry(
    Map<String, PageRegistry> flavors, {
    this.defaultFlavor = 'default',
    String? activeFlavor,
  }) : _activeFlavor = activeFlavor {
    registerFlavors(flavors);
  }

  /// Sets the currently active flavor.
  void setActiveFlavor(String flavor) {
    _activeFlavor = flavor.toLowerCase().trim();
  }

  /// Gets the currently active flavor, defaulting to [defaultFlavor].
  String get activeFlavor =>
      _activeFlavor ?? defaultFlavor.toLowerCase().trim();

  /// Registers a registry for [flavor].
  void registerFlavor(String flavor, PageRegistry registry) {
    _flavorRegistries[flavor.toLowerCase().trim()] = registry;
  }

  /// Registers multiple flavor registries.
  void registerFlavors(Map<String, PageRegistry> flavors) {
    for (final entry in flavors.entries) {
      registerFlavor(entry.key, entry.value);
    }
  }

  /// Resolves the underlying [PageRegistry] for [flavor].
  PageRegistry registryFor([String? flavor]) {
    final target = (flavor != null && flavor.isNotEmpty)
        ? flavor.toLowerCase().trim()
        : activeFlavor;

    return _flavorRegistries[target] ??
        _flavorRegistries[defaultFlavor.toLowerCase().trim()] ??
        this;
  }

  /// Resolves a page builder for [name] with flavor precedence:
  /// 1. Requested flavor's registry
  /// 2. Default flavor's registry
  /// 3. Root/shared pages registered directly on this registry
  FlintPageBuilder? resolveForFlavor(String name, [String? flavor]) {
    final target = (flavor != null && flavor.isNotEmpty)
        ? flavor.toLowerCase().trim()
        : activeFlavor;

    final targetRegistry = _flavorRegistries[target];
    final builder = targetRegistry?[name];
    if (builder != null) return builder;

    final defaultKey = defaultFlavor.toLowerCase().trim();
    if (target != defaultKey) {
      final defaultRegistry = _flavorRegistries[defaultKey];
      final fallback = defaultRegistry?[name];
      if (fallback != null) return fallback;
    }

    return super[name];
  }

  @override
  FlintPageBuilder? operator [](String name) {
    return resolveForFlavor(name, activeFlavor);
  }
}
