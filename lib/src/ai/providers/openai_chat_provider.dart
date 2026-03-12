import 'dart:convert';

import 'package:flint_dart/src/ai/providers/chat_provider.dart';
import 'package:flint_dart/src/ai/providers/http_client.dart';

/// Chat provider adapter for OpenAI-compatible chat completions.
class OpenAiChatProvider extends ChatProvider {
  final String? apiKey;
  final String? bearerToken;
  final Uri endpoint;
  final AiHttpClient httpClient;

  /// Creates an OpenAI chat provider using either an API key or bearer token.
  OpenAiChatProvider({
    this.apiKey,
    this.bearerToken,
    Uri? endpoint,
    AiHttpClient? httpClient,
  })  : endpoint =
            endpoint ?? Uri.parse('https://api.openai.com/v1/chat/completions'),
        httpClient = httpClient ?? RetryingAiHttpClient(DartIoAiHttpClient()) {
    if ((apiKey == null || apiKey!.isEmpty) &&
        (bearerToken == null || bearerToken!.isEmpty)) {
      throw ArgumentError(
        'OpenAiChatProvider requires apiKey or bearerToken.',
      );
    }
  }

  @override
  String get displayName => 'OpenAI';

  @override
  String get id => 'openai';

  @override
  Future<ChatResult> complete(ChatRequest request) async {
    final token = bearerToken ?? apiKey!;
    AiHttpResponse response;
    try {
      response = await httpClient.send(
        AiHttpRequest(
          method: 'POST',
          uri: endpoint,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'model': request.model,
            'messages':
                request.messages.map((message) => message.toMap()).toList(),
            if (request.temperature != null) 'temperature': request.temperature,
            if (request.maxTokens != null) 'max_tokens': request.maxTokens,
            ...request.metadata,
          }),
        ),
      );
    } catch (error) {
      throw AiProviderException(
        providerId: id,
        message: 'OpenAI request transport failed',
        cause: error,
      );
    }

    if (!response.isSuccess) {
      throw AiProviderException(
        providerId: id,
        message: 'OpenAI request failed',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final payload = Map<String, dynamic>.from(response.jsonBody() as Map);
    final choices = payload['choices'] as List? ?? const [];
    final message = choices.isEmpty
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(
            Map<String, dynamic>.from(choices.first as Map)['message'] as Map? ??
                const {},
          );
    final usage = Map<String, dynamic>.from(payload['usage'] as Map? ?? const {});

    return ChatResult(
      providerId: id,
      model: request.model,
      content: message['content']?.toString() ?? '',
      usage: ChatUsage(
        inputTokens: usage['prompt_tokens'] as int?,
        outputTokens: usage['completion_tokens'] as int?,
        totalTokens: usage['total_tokens'] as int?,
      ),
      raw: payload,
    );
  }
}
