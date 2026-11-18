class QueryParams {
  const QueryParams();

  String? get(String key) => null;
  List<String> getAll(String key) => const [];
  Map<String, String> get all => const {};
  Map<String, List<String>> get allValues => const {};
  bool has(String key) => false;
  void set(String key, Object? value, {bool push = false, Object? state}) {}
  void update(
    Map<String, Object?> values, {
    bool push = false,
    Object? state,
  }) {}
  void remove(String key, {bool push = false, Object? state}) {}
  void clear({bool push = false, Object? state}) {}
}

const query = QueryParams();
