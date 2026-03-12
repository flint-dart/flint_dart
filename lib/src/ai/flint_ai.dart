import 'package:flint_dart/src/ai/memory/memory_store.dart';
import 'package:flint_dart/src/ai/persistence/ai_repository.dart';
import 'package:flint_dart/src/ai/providers/chat_provider.dart';
import 'package:flint_dart/src/ai/providers/embedding_provider.dart';
import 'package:flint_dart/src/ai/providers/image_provider.dart';
import 'package:flint_dart/src/ai/providers/provider_registry.dart';
import 'package:flint_dart/src/ai/runtime/runtime.dart';
import 'package:flint_dart/src/ai/tools/tool.dart';
import 'package:flint_dart/src/ai/workflows/workflow.dart';
import 'package:flint_dart/src/context.dart';
import 'package:flint_dart/logs.dart';

/// Main facade for Flint's AI runtime.
class FlintAi {
  /// Registered chat, image, and embedding providers.
  final AiProviderRegistry providers;
  /// Registered executable AI tools.
  final AiToolRegistry tools;
  /// Registered named workflows.
  final AiWorkflowRegistry workflows;
  /// Run and thread memory storage.
  final AiMemoryStore memoryStore;
  /// Durable repository for runs, traces, threads, and artifacts.
  final AiRepository repository;
  /// Planner used to convert goals into execution steps.
  final AiPlanner planner;
  /// Executor used to run a plan.
  final AiExecutor executor;
  /// Policy used to authorize tool execution.
  AiToolPolicy toolPolicy;
  /// Indicates whether the default auto-configured memory store is in use.
  final bool usesAutoMemoryStore;

  /// Creates a new AI runtime with sensible defaults for development.
  FlintAi({
    AiProviderRegistry? providers,
    AiToolRegistry? tools,
    AiWorkflowRegistry? workflows,
    AiMemoryStore? memoryStore,
    AiRepository? repository,
    AiPlanner? planner,
    AiExecutor? executor,
    AiToolPolicy? toolPolicy,
  })  : providers = providers ?? AiProviderRegistry(),
        tools = tools ?? AiToolRegistry(),
        workflows = workflows ?? AiWorkflowRegistry(),
        memoryStore = memoryStore ?? AutoAiMemoryStore(),
        repository = repository ?? AutoAiRepository(),
        planner = planner ?? DefaultAiPlanner(),
        executor = executor ?? DefaultAiExecutor(),
        toolPolicy = toolPolicy ?? const SafeDefaultAiToolPolicy(),
        usesAutoMemoryStore = memoryStore == null {
    if (memoryStore == null) {
      Log.warning(
        'FlintAi is using auto-configured AI memory. Connect the database or provide a shared memory store for production.',
        tag: 'ai',
        );
    }
  }

  /// Creates an AI runtime configured for production-oriented defaults.
  factory FlintAi.production({
    AiProviderRegistry? providers,
    AiToolRegistry? tools,
    AiWorkflowRegistry? workflows,
    AiMemoryStore? memoryStore,
    AiRepository? repository,
    AiPlanner? planner,
    AiExecutor? executor,
    AiToolPolicy? toolPolicy,
  }) {
    return FlintAi(
      providers: providers,
      tools: tools,
      workflows: workflows,
      memoryStore: memoryStore ?? AutoAiMemoryStore(),
      repository: repository ?? AutoAiRepository(),
      planner: planner,
      executor: executor,
      toolPolicy: toolPolicy ?? const SafeDefaultAiToolPolicy(requireUserBinding: true),
    );
  }

  /// Registers a chat provider implementation.
  void registerChatProvider(ChatProvider provider) {
    providers.registerChatProvider(provider);
  }

  /// Registers an image generation provider implementation.
  void registerImageProvider(ImageProvider provider) {
    providers.registerImageProvider(provider);
  }

  /// Registers an embedding provider implementation.
  void registerEmbeddingProvider(EmbeddingProvider provider) {
    providers.registerEmbeddingProvider(provider);
  }

  /// Registers a tool that agents can invoke during execution.
  void registerTool(AiTool tool) {
    tools.register(tool);
  }

  /// Registers a named workflow.
  void registerWorkflow(AiWorkflow workflow) {
    workflows.register(workflow);
  }

  /// Sends a non-streaming chat request through the named provider.
  Future<ChatResult> chat({
    required String providerId,
    required ChatRequest request,
  }) async {
    final provider = providers.chatProvider(providerId);
    if (provider == null) {
      throw StateError('Unknown AI chat provider: $providerId');
    }
    return provider.complete(request);
  }

  /// Streams chat events from the named provider.
  Stream<ChatEvent> streamChat({
    required String providerId,
    required ChatRequest request,
  }) {
    final provider = providers.chatProvider(providerId);
    if (provider == null) {
      throw StateError('Unknown AI chat provider: $providerId');
    }
    return provider.stream(request);
  }

  /// Executes an agent run for the supplied [goal].
  Future<AiRunResult> run({
    required AiAgent agent,
    required AiGoal goal,
    String? userId,
    String? tenantId,
    String? threadId,
    Context? context,
  }) async {
    final run = AiRun(
      id: generateAiRunId(),
      agentName: agent.name,
      goal: goal,
      userId: userId,
      tenantId: tenantId,
      threadId: threadId,
    );

    final runContext = AiRunContext(
      run: run,
      memoryStore: memoryStore,
      repository: repository,
      requestContext: context,
      metadata: {
        'agent': agent.name,
        'threadId': threadId,
      },
    );

    run.status = AiRunStatus.planning;
    await runContext.persistRun();
    await runContext.addEvent('run.planning', payload: {
      'goal': goal.toMap(),
    });

    final plan = await planner.createPlan(agent, runContext);
    final result = await executor.execute(
      agent: agent,
      context: runContext,
      plan: plan,
      toolRegistry: tools,
      toolPolicy: toolPolicy,
    );

    await repository.runs?.saveRun(result.run.toMap());
    return result;
  }

  /// Loads persisted or in-memory events for a run.
  Future<List<Map<String, dynamic>>> loadRunEvents(String runId) {
    return memoryStore.loadRunEvents(runId);
  }

  /// Loads persisted or in-memory messages for a thread.
  Future<List<Map<String, dynamic>>> loadThreadMessages(String threadId) {
    return memoryStore.loadThreadMessages(threadId);
  }

  /// Saves a thread message into the configured memory store.
  Future<void> saveThreadMessage(
    String threadId,
    Map<String, dynamic> message,
  ) {
    return memoryStore.saveThreadMessage(threadId, message);
  }

  /// Executes a registered workflow by name.
  Future<AiWorkflowRunResult> runWorkflow(
    String workflowName, {
    String? userId,
    String? tenantId,
    String? threadId,
    Map<String, dynamic> input = const {},
    Context? context,
    Map<String, dynamic> metadata = const {},
    bool isBackground = false,
  }) async {
    final workflow = workflows.workflow(workflowName);
    if (workflow == null) {
      throw StateError('Unknown AI workflow: $workflowName');
    }

    final output = await workflow.run(
      AiWorkflowContext(
        userId: userId,
        tenantId: tenantId,
        threadId: threadId,
        input: input,
        requestContext: context,
        metadata: {
          'workflow': workflow.name,
          ...metadata,
        },
        runId: generateAiRunId(),
        isBackground: isBackground,
      ),
    );

    return AiWorkflowRunResult(
      workflowName: workflow.name,
      output: output,
    );
  }
}
