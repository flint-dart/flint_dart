import 'package:flint_dart/src/ai/providers/chat_provider.dart';
import 'package:flint_dart/src/ai/providers/embedding_provider.dart';
import 'package:flint_dart/src/ai/providers/image_provider.dart';

/// Registry for chat, image, and embedding providers.
class AiProviderRegistry {
  final Map<String, ChatProvider> _chatProviders = {};
  final Map<String, ImageProvider> _imageProviders = {};
  final Map<String, EmbeddingProvider> _embeddingProviders = {};

  /// Registers a chat provider by id.
  void registerChatProvider(ChatProvider provider) {
    _chatProviders[provider.id] = provider;
  }

  /// Registers an image provider by id.
  void registerImageProvider(ImageProvider provider) {
    _imageProviders[provider.id] = provider;
  }

  /// Registers an embedding provider by id.
  void registerEmbeddingProvider(EmbeddingProvider provider) {
    _embeddingProviders[provider.id] = provider;
  }

  /// Looks up a chat provider by id.
  ChatProvider? chatProvider(String id) => _chatProviders[id];
  /// Looks up an image provider by id.
  ImageProvider? imageProvider(String id) => _imageProviders[id];
  /// Looks up an embedding provider by id.
  EmbeddingProvider? embeddingProvider(String id) => _embeddingProviders[id];

  /// Returns descriptions for all registered providers.
  List<Map<String, dynamic>> describeAll() => [
        ..._chatProviders.values.map((provider) => provider.describe()),
        ..._imageProviders.values.map((provider) => provider.describe()),
        ..._embeddingProviders.values.map((provider) => provider.describe()),
      ];
}
