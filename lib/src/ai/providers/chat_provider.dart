/// Single chat message in a provider request.
class ChatMessage {
  final String role;
  final String content;
  final Map<String, dynamic> metadata;

  const ChatMessage({
    required this.role,
    required this.content,
    this.metadata = const {},
  });

  /// Serializes the message into a provider-friendly map.
  Map<String, dynamic> toMap() => {
        'role': role,
        'content': content,
        'metadata': metadata,
      };
}

/// Input payload for a chat completion request.
class ChatRequest {
  final String model;
  final List<ChatMessage> messages;
  final double? temperature;
  final int? maxTokens;
  final Map<String, dynamic> metadata;

  const ChatRequest({
    required this.model,
    required this.messages,
    this.temperature,
    this.maxTokens,
    this.metadata = const {},
  });
}

/// Token usage metadata returned by a provider.
class ChatUsage {
  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;

  const ChatUsage({
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
  });

  /// Serializes usage into a persistence-friendly map.
  Map<String, dynamic> toMap() => {
        'inputTokens': inputTokens,
        'outputTokens': outputTokens,
        'totalTokens': totalTokens,
      };
}

/// Non-streaming chat completion result.
class ChatResult {
  final String providerId;
  final String model;
  final String content;
  final ChatUsage usage;
  final Map<String, dynamic> raw;

  const ChatResult({
    required this.providerId,
    required this.model,
    required this.content,
    this.usage = const ChatUsage(),
    this.raw = const {},
  });

  /// Serializes the result into a persistence-friendly map.
  Map<String, dynamic> toMap() => {
        'providerId': providerId,
        'model': model,
        'content': content,
        'usage': usage.toMap(),
        'raw': raw,
      };
}

/// Streaming event emitted by a chat provider.
class ChatEvent {
  final String type;
  final Map<String, dynamic> payload;

  const ChatEvent({
    required this.type,
    this.payload = const {},
  });
}

/// Normalized provider exception used across AI adapters.
class AiProviderException implements Exception {
  final String providerId;
  final String message;
  final int? statusCode;
  final String? responseBody;
  final Object? cause;

  const AiProviderException({
    required this.providerId,
    required this.message,
    this.statusCode,
    this.responseBody,
    this.cause,
  });

  @override
  String toString() {
    final status = statusCode == null ? '' : ' ($statusCode)';
    return 'AiProviderException[$providerId]$status: $message';
  }
}

/// Contract for chat-capable AI providers.
abstract class ChatProvider {
  /// Stable provider id used for registration and lookup.
  String get id;
  /// Human-readable provider name.
  String get displayName;

  /// Executes a non-streaming completion request.
  Future<ChatResult> complete(ChatRequest request);

  /// Streams chat events for the request.
  Stream<ChatEvent> stream(ChatRequest request) async* {
    final result = await complete(request);
    yield ChatEvent(
      type: 'chat.completed',
      payload: result.toMap(),
    );
  }

  /// Returns a serializable description of the provider.
  Map<String, dynamic> describe() => {
        'id': id,
        'displayName': displayName,
        'capability': 'chat',
      };
}
