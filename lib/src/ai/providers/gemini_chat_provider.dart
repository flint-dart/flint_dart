import 'dart:convert';

import 'package:flint_dart/src/ai/providers/chat_provider.dart';
import 'package:flint_dart/src/ai/providers/http_client.dart';

/// Chat provider adapter for Google Gemini.
class GeminiChatProvider extends ChatProvider {
  final String? apiKey;
  final String? bearerToken;
  final Uri endpoint;
  final AiHttpClient httpClient;

  /// Creates a Gemini chat provider using either an API key or bearer token.
  GeminiChatProvider({
    this.apiKey,
    this.bearerToken,
    Uri? endpoint,
    AiHttpClient? httpClient,
  })  : endpoint = endpoint ??
            Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent',
            ),
        httpClient = httpClient ?? RetryingAiHttpClient(DartIoAiHttpClient()) {
    if ((apiKey == null || apiKey!.isEmpty) &&
        (bearerToken == null || bearerToken!.isEmpty)) {
      throw ArgumentError(
        'GeminiChatProvider requires apiKey or bearerToken.',
      );
    }
  }

  @override
  String get displayName => 'Google Gemini';

  @override
  String get id => 'gemini';

  @override
  Future<ChatResult> complete(ChatRequest request) async {
    final contents = request.messages
        .where((message) => message.role != 'system')
        .map((message) => {
              'role': message.role == 'assistant' ? 'model' : 'user',
              'parts': [
                {'text': message.content}
              ],
            })
        .toList(growable: false);

    final system = request.messages
        .where((message) => message.role == 'system')
        .map((message) => message.content)
        .join('\n');

    AiHttpResponse response;
    try {
      response = await httpClient.send(
        AiHttpRequest(
          method: 'POST',
          uri: endpoint,
          headers: {
            'Content-Type': 'application/json',
            if (bearerToken != null && bearerToken!.isNotEmpty)
              'Authorization': 'Bearer $bearerToken'
            else
              'x-goog-api-key': apiKey!,
          },
          body: jsonEncode({
            'contents': contents,
            if (system.isNotEmpty)
              'systemInstruction': {
                'parts': [
                  {'text': system}
                ],
              },
            if (request.temperature != null || request.maxTokens != null)
              'generationConfig': {
                if (request.temperature != null)
                  'temperature': request.temperature,
                if (request.maxTokens != null)
                  'maxOutputTokens': request.maxTokens,
              },
            ...request.metadata,
          }),
        ),
      );
    } catch (error) {
      throw AiProviderException(
        providerId: id,
        message: 'Gemini request transport failed',
        cause: error,
      );
    }

    if (!response.isSuccess) {
      throw AiProviderException(
        providerId: id,
        message: 'Gemini request failed',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final payload = Map<String, dynamic>.from(response.jsonBody() as Map);
    final candidates = payload['candidates'] as List? ?? const [];
    final content = candidates.isEmpty
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(
            Map<String, dynamic>.from(candidates.first as Map)['content']
                    as Map? ??
                const {},
          );
    final parts = content['parts'] as List? ?? const [];
    final firstPart = parts.isEmpty
        ? const <String, dynamic>{}
        : Map<String, dynamic>.from(parts.first as Map);
    final usage = Map<String, dynamic>.from(
      payload['usageMetadata'] as Map? ?? const {},
    );

    return ChatResult(
      providerId: id,
      model: request.model,
      content: firstPart['text']?.toString() ?? '',
      usage: ChatUsage(
        inputTokens: usage['promptTokenCount'] as int?,
        outputTokens: usage['candidatesTokenCount'] as int?,
        totalTokens: usage['totalTokenCount'] as int?,
      ),
      raw: payload,
    );
  }
}
