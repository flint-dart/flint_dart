import 'dart:convert';

import 'package:flint_dart/src/ai/providers/chat_provider.dart';
import 'package:flint_dart/src/ai/providers/http_client.dart';

/// Chat provider adapter for Anthropic's messages API.
class AnthropicChatProvider extends ChatProvider {
  final String apiKey;
  final Uri endpoint;
  final AiHttpClient httpClient;

  /// Creates an Anthropic chat provider using an API key.
  AnthropicChatProvider({
    required this.apiKey,
    Uri? endpoint,
    AiHttpClient? httpClient,
  })  : endpoint = endpoint ?? Uri.parse('https://api.anthropic.com/v1/messages'),
        httpClient = httpClient ?? RetryingAiHttpClient(DartIoAiHttpClient()) {
    if (apiKey.isEmpty) {
      throw ArgumentError('AnthropicChatProvider requires apiKey.');
    }
  }

  @override
  String get displayName => 'Anthropic';

  @override
  String get id => 'anthropic';

  @override
  Future<ChatResult> complete(ChatRequest request) async {
    String? system;
    final messages = <Map<String, dynamic>>[];

    for (final message in request.messages) {
      if (message.role == 'system') {
        system = system == null ? message.content : '$system\n${message.content}';
        continue;
      }
      messages.add({
        'role': message.role,
        'content': message.content,
      });
    }

    AiHttpResponse response;
    try {
      response = await httpClient.send(
        AiHttpRequest(
          method: 'POST',
          uri: endpoint,
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': apiKey,
            'anthropic-version': '2023-06-01',
          },
          body: jsonEncode({
            'model': request.model,
            'messages': messages,
            'max_tokens': request.maxTokens ?? 1024,
            if (request.temperature != null) 'temperature': request.temperature,
            if (system != null && system.isNotEmpty) 'system': system,
            ...request.metadata,
          }),
        ),
      );
    } catch (error) {
      throw AiProviderException(
        providerId: id,
        message: 'Anthropic request transport failed',
        cause: error,
      );
    }

    if (!response.isSuccess) {
      throw AiProviderException(
        providerId: id,
        message: 'Anthropic request failed',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final payload = Map<String, dynamic>.from(response.jsonBody() as Map);
    final content = payload['content'] as List? ?? const [];
    final first = content.isEmpty
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(content.first as Map);
    final usage = Map<String, dynamic>.from(payload['usage'] as Map? ?? const {});

    return ChatResult(
      providerId: id,
      model: request.model,
      content: first['text']?.toString() ?? '',
      usage: ChatUsage(
        inputTokens: usage['input_tokens'] as int?,
        outputTokens: usage['output_tokens'] as int?,
      ),
      raw: payload,
    );
  }
}
