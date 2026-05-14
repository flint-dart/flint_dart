/// Input payload for an embedding request.
class EmbeddingRequest {
  final String input;
  final String? model;
  final Map<String, dynamic> metadata;

  const EmbeddingRequest({
    required this.input,
    this.model,
    this.metadata = const {},
  });
}

/// Result payload for an embedding request.
class EmbeddingResult {
  final String providerId;
  final List<double> vector;
  final Map<String, dynamic> raw;

  const EmbeddingResult({
    required this.providerId,
    this.vector = const [],
    this.raw = const {},
  });

  /// Serializes the embedding result into a map.
  Map<String, dynamic> toMap() => {
        'providerId': providerId,
        'vector': vector,
        'raw': raw,
      };
}

/// Contract for embedding-capable AI providers.
abstract class EmbeddingProvider {
  /// Stable provider id used for registration and lookup.
  String get id;

  /// Human-readable provider name.
  String get displayName;

  /// Generates an embedding vector for the supplied request.
  Future<EmbeddingResult> embed(EmbeddingRequest request);

  /// Returns a serializable description of the provider.
  Map<String, dynamic> describe() => {
        'id': id,
        'displayName': displayName,
        'capability': 'embedding',
      };
}
