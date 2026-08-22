import '../client/client_router.dart';
import '../component.dart';
import '../state/state_signal.dart';

/// Builds a typed object from a JSON map returned by a FlintDart API.
typedef JsonModelFactory<T> = T Function(Map<String, dynamic> json);

/// Loads data for a [ResourceController].
typedef ResourceLoader<T> = Future<T> Function();

/// Builds UI from the current resource snapshot.
typedef ResourceBuilder<T> = View Function(ResourceSnapshot<T> snapshot);

/// Lifecycle state for an API-backed resource.
enum ResourceStatus {
  /// The resource has not been loaded yet.
  idle,

  /// A request is currently in flight.
  loading,

  /// Data was loaded successfully.
  success,

  /// The most recent request failed.
  error,
}

/// Immutable snapshot of an API-backed resource.
class ResourceSnapshot<T> {
  /// Creates a resource snapshot.
  const ResourceSnapshot({
    this.status = ResourceStatus.idle,
    this.data,
    this.error,
    this.updatedAt,
  });

  /// Current lifecycle status.
  final ResourceStatus status;

  /// Current data, when available.
  final T? data;

  /// Current error, when the latest request failed.
  final Object? error;

  /// Last time data or an error was written.
  final DateTime? updatedAt;

  /// Whether no request has been made yet.
  bool get isIdle => status == ResourceStatus.idle;

  /// Whether a request is currently running.
  bool get isLoading => status == ResourceStatus.loading;

  /// Whether data is available from a successful request or server props.
  bool get isSuccess => status == ResourceStatus.success;

  /// Whether the most recent request failed.
  bool get isError => status == ResourceStatus.error;

  /// Whether [data] is not null.
  bool get hasData => data != null;

  /// Creates a modified snapshot.
  ResourceSnapshot<T> copyWith({
    ResourceStatus? status,
    T? data,
    Object? error,
    DateTime? updatedAt,
    bool clearError = false,
  }) {
    return ResourceSnapshot<T>(
      status: status ?? this.status,
      data: data ?? this.data,
      error: clearError ? null : error ?? this.error,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Reactive controller for loading and refreshing API data.
///
/// A resource is Flint UI's recommended shape for data that comes from a
/// FlintDart endpoint. It keeps request status, current data, errors, and local
/// optimistic updates in one signal.
class ResourceController<T> {
  /// Creates a resource controller.
  ResourceController({
    required this.loader,
    T? initialData,
    bool loadImmediately = false,
  }) : state = StateSignal<ResourceSnapshot<T>>(
         ResourceSnapshot<T>(
           status: initialData == null
               ? ResourceStatus.idle
               : ResourceStatus.success,
           data: initialData,
           updatedAt: initialData == null ? null : DateTime.now(),
         ),
       ) {
    if (loadImmediately) {
      load(silent: initialData != null);
    }
  }

  /// The function used to fetch fresh data.
  final ResourceLoader<T> loader;

  /// Reactive snapshot signal.
  final StateSignal<ResourceSnapshot<T>> state;

  /// Current resource snapshot.
  ResourceSnapshot<T> get snapshot => state.value;

  /// Current data, when available.
  T? get data => snapshot.data;

  /// Loads fresh data.
  ///
  /// When [silent] is true, existing data stays visible and the status is not
  /// changed to loading. This is useful for background refreshes.
  Future<T?> load({bool silent = false}) async {
    if (!silent) {
      state.value = snapshot.copyWith(
        status: ResourceStatus.loading,
        clearError: true,
      );
    }

    try {
      final loaded = await loader();
      setData(loaded);
      return loaded;
    } catch (error) {
      setError(error);
      return null;
    }
  }

  /// Alias for [load] used by dashboard refresh buttons.
  Future<T?> refresh({bool silent = false}) => load(silent: silent);

  /// Replaces the current data.
  void setData(T data) {
    state.value = ResourceSnapshot<T>(
      status: ResourceStatus.success,
      data: data,
      updatedAt: DateTime.now(),
    );
  }

  /// Applies a local mutation to the current data.
  void mutate(T Function(T? current) updater) {
    setData(updater(snapshot.data));
  }

  /// Marks the resource as failed.
  void setError(Object error) {
    state.value = ResourceSnapshot<T>(
      status: ResourceStatus.error,
      data: snapshot.data,
      error: error,
      updatedAt: DateTime.now(),
    );
  }

  /// Clears listeners owned by this resource.
  void dispose() {
    state.dispose();
  }
}

/// Rebuilds when a [ResourceController] changes.
class ResourceView<T> extends StatelessComponent {
  /// Creates a resource view.
  ResourceView(this.resource, this.builder);

  /// Resource controller to observe.
  ResourceController<T> resource;

  /// Builder that receives the current snapshot.
  ResourceBuilder<T> builder;

  @override
  View build() =>
      StateSignalListener<ResourceSnapshot<T>>(resource.state, builder);

  @override
  void updateFrom(covariant ResourceView<T> next) {
    resource = next.resource;
    builder = next.builder;
  }
}

/// Lightweight browser-side record that mirrors a FlintDart model payload.
///
/// Do not import server-side `Model` classes into browser UI code. Those
/// classes depend on database/server APIs. Use this record, a typed DTO, or a
/// generated client model instead.
class FlintModelRecord {
  /// Creates a model record from JSON.
  const FlintModelRecord(this.attributes);

  /// Raw model attributes.
  final Map<String, dynamic> attributes;

  /// Common model id field.
  Object? get id => attributes['id'];

  /// Reads a raw attribute by [key].
  Object? operator [](String key) => attributes[key];

  /// Reads an attribute as a string.
  String? string(String key) => attributes[key]?.toString();

  /// Reads an attribute as an integer.
  int? integer(String key) {
    final value = attributes[key];
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '');
  }

  /// Reads an attribute as a double.
  double? decimal(String key) {
    final value = attributes[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  /// Converts this record back to a map.
  Map<String, dynamic> toMap() => Map<String, dynamic>.from(attributes);
}

/// Browser client for conventional FlintDart model/resource endpoints.
///
/// It expects the common FlintDart response envelope:
///
/// ```json
/// {"status": "success", "data": {...}}
/// ```
///
/// Plain list/object responses are also accepted.
class FlintModelApi<T> {
  /// Creates a model API client.
  FlintModelApi({
    required this.path,
    required this.fromJson,
    ClientRouter? router,
  }) : router = router ?? clientRouter;

  /// Creates an API that returns [FlintModelRecord] objects.
  factory FlintModelApi.records(String path, {ClientRouter? router}) {
    return FlintModelApi<FlintModelRecord>(
          path: path,
          router: router,
          fromJson: (json) => FlintModelRecord(json),
        )
        as FlintModelApi<T>;
  }

  /// Base API path, for example `/plans`.
  final String path;

  /// Router used for HTTP calls.
  final ClientRouter router;

  /// Converts response JSON into a client model.
  final JsonModelFactory<T> fromJson;

  /// Lists records from `GET path`.
  Future<List<T>> list({Map<String, dynamic>? query}) async {
    final response = await router.get<Map<String, dynamic>>(path, query: query);
    if (response.isError) throw response.error!;
    return _toList(_unwrap(response.data));
  }

  /// Fetches one record from `GET path/:id`.
  Future<T> find(Object id) async {
    final response = await router.get<Map<String, dynamic>>('$path/$id');
    if (response.isError) throw response.error!;
    return _toModel(_unwrap(response.data));
  }

  /// Creates a record with `POST path`.
  Future<T> create(Map<String, dynamic> data) async {
    final response = await router.post<Map<String, dynamic>>(path, body: data);
    if (response.isError) throw response.error!;
    return _toModel(_unwrap(response.data));
  }

  /// Updates a record with `PUT path/:id`.
  Future<T> update(Object id, Map<String, dynamic> data) async {
    final response = await router.put<Map<String, dynamic>>(
      '$path/$id',
      body: data,
    );
    if (response.isError) throw response.error!;
    return _toModel(_unwrap(response.data));
  }

  /// Deletes a record with `DELETE path/:id`.
  Future<void> delete(Object id) async {
    final response = await router.delete<Map<String, dynamic>>('$path/$id');
    if (response.isError) throw response.error!;
  }

  Object? _unwrap(Object? payload) {
    if (payload is Map && payload.containsKey('data')) return payload['data'];
    return payload;
  }

  List<T> _toList(Object? payload) {
    if (payload is List) {
      return payload.whereType<Map>().map((item) {
        return fromJson(
          item.map((key, value) => MapEntry(key.toString(), value)),
        );
      }).toList();
    }
    return const [];
  }

  T _toModel(Object? payload) {
    if (payload is! Map) {
      throw StateError('Expected a JSON object but received $payload.');
    }
    return fromJson(
      payload.map((key, value) => MapEntry(key.toString(), value)),
    );
  }
}
