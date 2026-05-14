/// Input payload for an image generation request.
class ImageGenerationRequest {
  final String prompt;
  final String? model;
  final String? size;
  final Map<String, dynamic> metadata;

  const ImageGenerationRequest({
    required this.prompt,
    this.model,
    this.size,
    this.metadata = const {},
  });
}

/// Result payload for an image generation request.
class ImageGenerationResult {
  final String providerId;
  final List<String> urls;
  final Map<String, dynamic> raw;

  const ImageGenerationResult({
    required this.providerId,
    this.urls = const [],
    this.raw = const {},
  });

  /// Serializes the image generation result into a map.
  Map<String, dynamic> toMap() => {
        'providerId': providerId,
        'urls': urls,
        'raw': raw,
      };
}

/// Contract for image-capable AI providers.
abstract class ImageProvider {
  /// Stable provider id used for registration and lookup.
  String get id;

  /// Human-readable provider name.
  String get displayName;

  /// Generates image outputs for the supplied request.
  Future<ImageGenerationResult> generate(ImageGenerationRequest request);

  /// Returns a serializable description of the provider.
  Map<String, dynamic> describe() => {
        'id': id,
        'displayName': displayName,
        'capability': 'image',
      };
}
