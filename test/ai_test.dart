import 'dart:io';

import 'package:flint_dart/flint_dart.dart';
import 'package:test/test.dart';

import 'helpers/fakes.dart';

void main() {
  group('FlintAi', () {
    test('runs a basic agent end to end', () async {
      final ai = FlintAi();

      final result = await ai.run(
        agent: BasicTaskAgent(),
        goal: const AiGoal(
          task: 'Summarize an order',
          input: {'orderId': 'ord_1'},
        ),
        userId: 'user-1',
      );

      expect(result.run.status, AiRunStatus.completed);
      expect(result.output['task'], 'Summarize an order');
      expect((result.output['state'] as Map)['capture_goal'], isNotNull);
    });

    test('executes registered tools through the default executor', () async {
      final ai = FlintAi();
      ai.registerTool(_EchoAiTool());

      final result = await ai.run(
        agent: _ToolAgent(),
        goal: const AiGoal(task: 'Use tool'),
        userId: 'user-2',
      );

      expect(result.run.status, AiRunStatus.completed);
      expect(result.output['toolResult'], 'hello');
    });

    test('denies tools that are not safe by default', () async {
      final ai = FlintAi();
      ai.registerTool(_RestrictedAiTool());

      expect(
        () => ai.run(
          agent: _RestrictedToolAgent(),
          goal: const AiGoal(task: 'Use restricted tool'),
          userId: 'user-2',
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Tool execution forbidden'),
          ),
        ),
      );
    });

    test('runs registered workflows', () async {
      final ai = FlintAi();
      ai.registerWorkflow(_EchoWorkflow());

      final result = await ai.runWorkflow(
        'echo_workflow',
        userId: 'user-3',
        input: const {'message': 'hi'},
      );

      expect(result.workflowName, 'echo_workflow');
      expect(result.output['message'], 'hi');
      expect(result.output['userId'], 'user-3');
    });

    test('persists runs and traces through the configured repository', () async {
      final runStore = InMemoryAiRunStore();
      final traceStore = InMemoryAiTraceStore();
      final ai = FlintAi(
        repository: AiRepository(
          runs: runStore,
          traces: traceStore,
        ),
      );

      final result = await ai.run(
        agent: BasicTaskAgent(),
        goal: const AiGoal(task: 'Persist this run'),
        userId: 'user-9',
      );

      final savedRun = await runStore.loadRun(result.run.id);
      final traces = traceStore.eventsForRun(result.run.id);

      expect(savedRun, isNotNull);
      expect(savedRun!['status'], AiRunStatus.completed.name);
      expect(
        traces.any((event) => event['type'] == 'run.completed'),
        isTrue,
      );
    });

    test('executes OpenAI chat provider through ai namespace', () async {
      final http = _FakeAiHttpClient([
        const AiHttpResponse(
          statusCode: 200,
          body:
              '{"choices":[{"message":{"content":"Hello from OpenAI"}}],"usage":{"prompt_tokens":3,"completion_tokens":4,"total_tokens":7}}',
        ),
      ]);
      final ai = FlintAi();
      ai.registerChatProvider(
        OpenAiChatProvider(
          apiKey: 'openai-key',
          httpClient: http,
        ),
      );

      final result = await ai.chat(
        providerId: 'openai',
        request: const ChatRequest(
          model: 'gpt-4o-mini',
          messages: [
            ChatMessage(role: 'user', content: 'hello'),
          ],
        ),
      );

      expect(result.content, 'Hello from OpenAI');
      expect(http.requests.single.headers['Authorization'], 'Bearer openai-key');
      expect(result.usage.totalTokens, 7);
    });

    test('executes Gemini chat provider with bearer auth through ai namespace',
        () async {
      final http = _FakeAiHttpClient([
        const AiHttpResponse(
          statusCode: 200,
          body:
              '{"candidates":[{"content":{"parts":[{"text":"Hello from Gemini"}]}}],"usageMetadata":{"promptTokenCount":5,"candidatesTokenCount":6,"totalTokenCount":11}}',
        ),
      ]);
      final ai = FlintAi();
      ai.registerChatProvider(
        GeminiChatProvider(
          bearerToken: 'gemini-token',
          httpClient: http,
        ),
      );

      final result = await ai.chat(
        providerId: 'gemini',
        request: const ChatRequest(
          model: 'gemini-2.0-flash',
          messages: [
            ChatMessage(role: 'user', content: 'hello'),
          ],
        ),
      );

      expect(result.content, 'Hello from Gemini');
      expect(
        http.requests.single.headers['Authorization'],
        'Bearer gemini-token',
      );
      expect(result.usage.totalTokens, 11);
    });

    test('executes Anthropic chat provider through ai namespace', () async {
      final http = _FakeAiHttpClient([
        const AiHttpResponse(
          statusCode: 200,
          body:
              '{"content":[{"text":"Hello from Anthropic"}],"usage":{"input_tokens":8,"output_tokens":9}}',
        ),
      ]);
      final ai = FlintAi();
      ai.registerChatProvider(
        AnthropicChatProvider(
          apiKey: 'anthropic-key',
          httpClient: http,
        ),
      );

      final result = await ai.chat(
        providerId: 'anthropic',
        request: const ChatRequest(
          model: 'claude-3-5-sonnet-latest',
          messages: [
            ChatMessage(role: 'user', content: 'hello'),
          ],
        ),
      );

      expect(result.content, 'Hello from Anthropic');
      expect(http.requests.single.headers['x-api-key'], 'anthropic-key');
      expect(result.usage.inputTokens, 8);
      expect(result.usage.outputTokens, 9);
    });

    test('streamChat exposes provider stream events', () async {
      final ai = FlintAi();
      ai.registerChatProvider(_StreamingChatProvider());

      final events = await ai
          .streamChat(
            providerId: 'streaming-chat',
            request: const ChatRequest(
              model: 'stream-model',
              messages: [ChatMessage(role: 'user', content: 'hello')],
            ),
          )
          .toList();

      expect(events, hasLength(2));
      expect(events.last.type, 'chat.completed');
      expect(events.last.payload['content'], 'streamed: hello');
    });

    test('memory store exposes saved thread messages through public API',
        () async {
      final ai = FlintAi(memoryStore: InMemoryAiMemoryStore());

      await ai.saveThreadMessage('thread-1', const {'role': 'user', 'content': 'hi'});
      final messages = await ai.loadThreadMessages('thread-1');

      expect(messages, hasLength(1));
      expect(messages.first['content'], 'hi');
    });

    test('retrying http client retries retryable responses', () async {
      final inner = _FlakyAiHttpClient(
        responses: [
          const AiHttpResponse(statusCode: 429, body: 'rate limited'),
          const AiHttpResponse(
            statusCode: 200,
            body:
                '{"choices":[{"message":{"content":"Recovered"}}],"usage":{"total_tokens":1}}',
          ),
        ],
      );
      final provider = OpenAiChatProvider(
        apiKey: 'openai-key',
        httpClient: RetryingAiHttpClient(
          inner,
          retryPolicy: const AiRetryPolicy(
            maxAttempts: 2,
            baseDelay: Duration.zero,
          ),
        ),
      );

      final result = await provider.complete(
        const ChatRequest(
          model: 'gpt-4o-mini',
          messages: [ChatMessage(role: 'user', content: 'retry')],
        ),
      );

      expect(result.content, 'Recovered');
      expect(inner.requests, hasLength(2));
    });

    test('providers throw normalized provider exceptions', () async {
      final provider = OpenAiChatProvider(
        apiKey: 'openai-key',
        httpClient: _ThrowingAiHttpClient(),
      );

      expect(
        () => provider.complete(
          const ChatRequest(
            model: 'gpt-4o-mini',
            messages: [ChatMessage(role: 'user', content: 'hello')],
          ),
        ),
        throwsA(
          isA<AiProviderException>().having(
            (error) => error.providerId,
            'providerId',
            'openai',
          ),
        ),
      );
    });
  });

  group('Framework integration', () {
    test('app.ai and ctx.ai use the same runtime instance', () async {
      final app = Flint(
        autoConnectDb: false,
        autoConnectMail: false,
        withDefaultMiddleware: false,
        enableSwaggerDocs: false,
      );

      Future<Object?> handler(Context ctx) async {
        final sameInstance = identical(app.ai, ctx.ai);
        return ctx.res!.json({
          'sameInstance': sameInstance,
          'providers': ctx.ai.providers.describeAll().length,
        });
      }

      app.get('/ai', handler as Handler);

      final request = FakeHttpRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/ai'),
      );

      await app.handleRequest(request);
      final response = request.response as FakeHttpResponse;

      expect(response.statusCode, HttpStatus.ok);
      expect(response.buffer.toString(), contains('"sameInstance":true'));
    });

    test('ctx.ai can execute an agent from an HTTP route', () async {
      final app = Flint(
        autoConnectDb: false,
        autoConnectMail: false,
        withDefaultMiddleware: false,
        enableSwaggerDocs: false,
      );

      app.get('/ai-run', (Context ctx) async {
        final result = await ctx.ai.run(
          agent: BasicTaskAgent(),
          goal: const AiGoal(
            task: 'Handle support request',
            input: {'ticketId': 'T-42'},
          ),
          userId: 'user-http',
          context: ctx,
        );

        return ctx.res!.json({
          'status': result.run.status.name,
          'task': result.output['task'],
        });
      });

      final request = FakeHttpRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/ai-run'),
      );

      await app.handleRequest(request);
      final response = request.response as FakeHttpResponse;

      expect(response.statusCode, HttpStatus.ok);
      expect(response.buffer.toString(), contains('"status":"completed"'));
      expect(response.buffer.toString(), contains('"task":"Handle support request"'));
    });

    test('workflow context carries request and metadata', () async {
      final app = Flint(
        autoConnectDb: false,
        autoConnectMail: false,
        withDefaultMiddleware: false,
        enableSwaggerDocs: false,
      );

      app.ai.registerWorkflow(_ContextWorkflow());

      app.get('/ai-workflow', (Context ctx) async {
        final result = await ctx.ai.runWorkflow(
          'context_workflow',
          userId: 'workflow-user',
          context: ctx,
          metadata: const {'source': 'route'},
          input: const {'message': 'ok'},
        );

        return ctx.res!.json(result.output);
      });

      final request = FakeHttpRequest(
        method: 'GET',
        uri: Uri.parse('http://localhost/ai-workflow'),
      );

      await app.handleRequest(request);
      final response = request.response as FakeHttpResponse;

      expect(response.statusCode, HttpStatus.ok);
      expect(response.buffer.toString(), contains('"hasContext":true'));
      expect(response.buffer.toString(), contains('"source":"route"'));
    });
  });
}

class _EchoAiTool extends AiTool {
  @override
  bool get enabledByDefault => true;

  @override
  String get description => 'Echoes the message argument.';

  @override
  String get name => 'echo_tool';

  @override
  Future<Map<String, dynamic>> execute(AiToolContext context) async {
    return {
      'message': context.arguments['message'],
      'userId': context.userId,
    };
  }
}

class _RestrictedAiTool extends AiTool {
  @override
  String get description => 'Restricted tool.';

  @override
  String get name => 'restricted_tool';

  @override
  Future<Map<String, dynamic>> execute(AiToolContext context) async {
    return const {'ok': true};
  }
}

class _ToolAgent extends AiAgent {
  @override
  String get name => 'tool_agent';

  @override
  Future<AiPlan> plan(AiRunContext context) async {
    return const AiPlan(
      steps: [
        AiPlanStep(
          id: 'echo',
          type: 'tool',
          description: 'Echo a value',
          toolName: 'echo_tool',
          arguments: {'message': 'hello'},
        ),
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> synthesize(AiRunContext context) async {
    return {
      'toolResult': (context.state['echo'] as Map)['message'],
    };
  }
}

class _RestrictedToolAgent extends AiAgent {
  @override
  String get name => 'restricted_tool_agent';

  @override
  Future<AiPlan> plan(AiRunContext context) async {
    return const AiPlan(
      steps: [
        AiPlanStep(
          id: 'restricted',
          type: 'tool',
          description: 'Use restricted tool',
          toolName: 'restricted_tool',
        ),
      ],
    );
  }
}

class _EchoWorkflow extends AiWorkflow {
  @override
  String get description => 'Returns the workflow input.';

  @override
  String get name => 'echo_workflow';

  @override
  Future<Map<String, dynamic>> run(AiWorkflowContext context) async {
    return {
      'message': context.input['message'],
      'userId': context.userId,
    };
  }
}

class _ContextWorkflow extends AiWorkflow {
  @override
  String get description => 'Exposes workflow context.';

  @override
  String get name => 'context_workflow';

  @override
  Future<Map<String, dynamic>> run(AiWorkflowContext context) async {
    return {
      'hasContext': context.requestContext != null,
      'source': context.metadata['source'],
      'message': context.input['message'],
    };
  }
}

class _FakeAiHttpClient implements AiHttpClient {
  final List<AiHttpResponse> _responses;
  final List<AiHttpRequest> requests = [];

  _FakeAiHttpClient(this._responses);

  @override
  Future<AiHttpResponse> send(AiHttpRequest request) async {
    requests.add(request);
    if (_responses.isEmpty) {
      throw StateError('No fake HTTP responses left.');
    }
    return _responses.removeAt(0);
  }
}

class _FlakyAiHttpClient implements AiHttpClient {
  final List<AiHttpResponse> responses;
  final List<AiHttpRequest> requests = [];

  _FlakyAiHttpClient({required this.responses});

  @override
  Future<AiHttpResponse> send(AiHttpRequest request) async {
    requests.add(request);
    return responses.removeAt(0);
  }
}

class _ThrowingAiHttpClient implements AiHttpClient {
  @override
  Future<AiHttpResponse> send(AiHttpRequest request) async {
    throw const AiHttpException('boom');
  }
}

class _StreamingChatProvider extends ChatProvider {
  @override
  String get displayName => 'Streaming Example';

  @override
  String get id => 'streaming-chat';

  @override
  Future<ChatResult> complete(ChatRequest request) async {
    return ChatResult(
      providerId: id,
      model: request.model,
      content: 'streamed: ${request.messages.last.content}',
    );
  }

  @override
  Stream<ChatEvent> stream(ChatRequest request) async* {
    yield const ChatEvent(type: 'chat.delta', payload: {'chunk': 'streamed'});
    yield ChatEvent(
      type: 'chat.completed',
      payload: {
        'content': 'streamed: ${request.messages.last.content}',
      },
    );
  }
}
