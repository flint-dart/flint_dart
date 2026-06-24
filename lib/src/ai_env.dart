import 'package:flint_ai/flint_ai.dart';

import 'env_parser.dart';

/// Environment-backed setup helpers for Flint AI.
extension FlintAiEnvSetup on FlintAi {
  /// Registers OpenAI when `OPENAI_API_KEY` or `OPENAI_BEARER_TOKEN` is set.
  bool useOpenAiFromEnv({
    String apiKeyKey = 'OPENAI_API_KEY',
    String bearerTokenKey = 'OPENAI_BEARER_TOKEN',
    String endpointKey = 'OPENAI_CHAT_ENDPOINT',
    AiHttpClient? httpClient,
  }) {
    final apiKey = _envValue(apiKeyKey);
    final bearerToken = _envValue(bearerTokenKey);
    if (apiKey == null && bearerToken == null) return false;

    registerChatProvider(
      OpenAiChatProvider(
        apiKey: apiKey,
        bearerToken: bearerToken,
        endpoint: _envUri(endpointKey),
        httpClient: httpClient,
      ),
    );
    return true;
  }

  /// Registers Gemini when `GEMINI_API_KEY` or `GEMINI_BEARER_TOKEN` is set.
  bool useGeminiFromEnv({
    String apiKeyKey = 'GEMINI_API_KEY',
    String bearerTokenKey = 'GEMINI_BEARER_TOKEN',
    String endpointKey = 'GEMINI_CHAT_ENDPOINT',
    AiHttpClient? httpClient,
  }) {
    final apiKey = _envValue(apiKeyKey);
    final bearerToken = _envValue(bearerTokenKey);
    if (apiKey == null && bearerToken == null) return false;

    registerChatProvider(
      GeminiChatProvider(
        apiKey: apiKey,
        bearerToken: bearerToken,
        endpoint: _envUri(endpointKey),
        httpClient: httpClient,
      ),
    );
    return true;
  }

  /// Registers Anthropic when `ANTHROPIC_API_KEY` is set.
  bool useAnthropicFromEnv({
    String apiKeyKey = 'ANTHROPIC_API_KEY',
    String endpointKey = 'ANTHROPIC_CHAT_ENDPOINT',
    AiHttpClient? httpClient,
  }) {
    final apiKey = _envValue(apiKeyKey);
    if (apiKey == null) return false;

    registerChatProvider(
      AnthropicChatProvider(
        apiKey: apiKey,
        endpoint: _envUri(endpointKey),
        httpClient: httpClient,
      ),
    );
    return true;
  }

  /// Registers every supported chat provider with credentials present in env.
  List<String> useChatProvidersFromEnv({AiHttpClient? httpClient}) {
    final registered = <String>[];
    if (useOpenAiFromEnv(httpClient: httpClient)) {
      registered.add('openai');
    }
    if (useGeminiFromEnv(httpClient: httpClient)) {
      registered.add('gemini');
    }
    if (useAnthropicFromEnv(httpClient: httpClient)) {
      registered.add('anthropic');
    }
    return registered;
  }

  /// Applies a production tool policy from env allow-lists.
  ///
  /// Supported env keys:
  /// - `AI_ALLOWED_TOOLS`: comma-separated exact tool names.
  /// - `AI_ALLOWED_CAPABILITIES`: comma-separated capability names.
  /// - `AI_ALLOWED_ROLES`: comma-separated role names.
  void useProductionToolPolicyFromEnv({
    String allowedToolsKey = 'AI_ALLOWED_TOOLS',
    String allowedCapabilitiesKey = 'AI_ALLOWED_CAPABILITIES',
    String allowedRolesKey = 'AI_ALLOWED_ROLES',
    bool requireUserBinding = true,
    bool allowEnabledByDefault = false,
  }) {
    toolPolicy = ProductionAiToolPolicy(
      allowedTools: _envSet(allowedToolsKey),
      allowedCapabilities: _envSet(allowedCapabilitiesKey),
      allowedRoles: _envSet(allowedRolesKey),
      requireUserBinding: requireUserBinding,
      allowEnabledByDefault: allowEnabledByDefault,
    );
  }
}

String? _envValue(String key) {
  final value = FlintEnv.get(key).trim();
  return value.isEmpty ? null : value;
}

Uri? _envUri(String key) {
  final value = _envValue(key);
  return value == null ? null : Uri.parse(value);
}

Set<String> _envSet(String key) {
  final value = _envValue(key);
  if (value == null) return const {};
  return value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
}
