import 'dart:math';

import 'package:flint_dart/src/ai/memory/memory_store.dart';
import 'package:flint_dart/src/ai/persistence/ai_repository.dart';
import 'package:flint_dart/src/ai/providers/chat_provider.dart';
import 'package:flint_dart/src/ai/tools/tool.dart';
import 'package:flint_dart/src/context.dart';

/// Lifecycle states for an AI run.
enum AiRunStatus {
  pending,
  planning,
  running,
  waitingForTool,
  waitingForHuman,
  completed,
  failed,
  cancelled,
}

/// High-level task submitted to an agent.
class AiGoal {
  final String task;
  final Map<String, dynamic> input;

  const AiGoal({
    required this.task,
    this.input = const {},
  });

  /// Serializes the goal into a persistence-friendly map.
  Map<String, dynamic> toMap() => {
        'task': task,
        'input': input,
      };
}

/// A single executable step in an AI plan.
class AiPlanStep {
  final String id;
  final String type;
  final String description;
  final String? toolName;
  final Map<String, dynamic> arguments;

  const AiPlanStep({
    required this.id,
    required this.type,
    required this.description,
    this.toolName,
    this.arguments = const {},
  });

  /// Serializes the step into a persistence-friendly map.
  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'description': description,
        'toolName': toolName,
        'arguments': arguments,
      };
}

/// Ordered collection of steps produced by a planner.
class AiPlan {
  final List<AiPlanStep> steps;
  final Map<String, dynamic> metadata;

  const AiPlan({
    required this.steps,
    this.metadata = const {},
  });

  /// Serializes the plan into a persistence-friendly map.
  Map<String, dynamic> toMap() => {
        'steps': steps.map((step) => step.toMap()).toList(),
        'metadata': metadata,
      };
}

/// Timestamped event emitted during a run.
class AiEvent {
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> payload;

  const AiEvent({
    required this.type,
    required this.timestamp,
    this.payload = const {},
  });

  /// Serializes the event into a persistence-friendly map.
  Map<String, dynamic> toMap() => {
        'type': type,
        'timestamp': timestamp.toIso8601String(),
        'payload': payload,
      };
}

/// Mutable state container for an individual agent execution.
class AiRun {
  final String id;
  final String agentName;
  final String? userId;
  final String? tenantId;
  final String? threadId;
  final AiGoal goal;
  AiRunStatus status;
  final Map<String, dynamic> state;
  final List<AiEvent> events;
  Map<String, dynamic>? output;

  AiRun({
    required this.id,
    required this.agentName,
    required this.goal,
    this.userId,
    this.tenantId,
    this.threadId,
    this.status = AiRunStatus.pending,
    Map<String, dynamic>? state,
    List<AiEvent>? events,
    this.output,
  })  : state = Map<String, dynamic>.from(state ?? const {}),
        events = List<AiEvent>.from(events ?? const []);

  /// Serializes the run into a persistence-friendly map.
  Map<String, dynamic> toMap() => {
        'id': id,
        'agentName': agentName,
        'userId': userId,
        'tenantId': tenantId,
        'threadId': threadId,
        'goal': goal.toMap(),
        'status': status.name,
        'state': state,
        'events': events.map((event) => event.toMap()).toList(),
        'output': output,
      };
}

/// Shared execution context available to planners, executors, and agents.
class AiRunContext {
  final AiRun run;
  final AiMemoryStore memoryStore;
  final AiRepository repository;
  final Context? requestContext;
  final ChatProvider? defaultChatProvider;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> artifacts;

  AiRunContext({
    required this.run,
    required this.memoryStore,
    required this.repository,
    this.requestContext,
    this.defaultChatProvider,
    Map<String, dynamic> metadata = const {},
    Map<String, dynamic> artifacts = const {},
  })  : metadata = Map<String, dynamic>.from(metadata),
        artifacts = Map<String, dynamic>.from(artifacts);

  /// Stable identifier for the current run.
  String get runId => run.id;

  /// Bound user identifier, when present.
  String? get userId => run.userId;

  /// Bound tenant identifier, when present.
  String? get tenantId => run.tenantId;

  /// Mutable run state accumulated during execution.
  Map<String, dynamic> get state => run.state;

  /// Current agent goal.
  AiGoal get goal => run.goal;

  /// Persists the current run snapshot.
  Future<void> persistRun() {
    return repository.runs?.saveRun(run.toMap()) ?? Future.value();
  }

  /// Appends a run event and persists it to the configured stores.
  Future<void> addEvent(
    String type, {
    Map<String, dynamic> payload = const {},
  }) async {
    final event = AiEvent(
      type: type,
      timestamp: DateTime.now(),
      payload: payload,
    );
    run.events.add(event);
    await memoryStore.appendRunEvent(run.id, event.toMap());
    await repository.traces?.appendTrace(run.id, event.toMap());
    await persistRun();
  }

  /// Persists an artifact produced during the run.
  Future<void> saveArtifact(
    String kind,
    Map<String, dynamic> artifact, {
    String? id,
  }) async {
    final artifactId =
        id ?? '${run.id}-${DateTime.now().microsecondsSinceEpoch}';
    artifacts[artifactId] = {
      'id': artifactId,
      'kind': kind,
      ...artifact,
    };
    await repository.artifacts?.saveArtifact({
      'id': artifactId,
      'runId': run.id,
      'kind': kind,
      'userId': userId,
      'tenantId': tenantId,
      ...artifact,
    });
  }
}

/// Final output of an agent run.
class AiRunResult {
  final AiRun run;
  final Map<String, dynamic> output;

  const AiRunResult({
    required this.run,
    required this.output,
  });

  /// Serializes the run result into a persistence-friendly map.
  Map<String, dynamic> toMap() => {
        'run': run.toMap(),
        'output': output,
      };
}

/// Contract implemented by runnable agents.
abstract class AiAgent {
  /// Stable agent name used in runs and logs.
  String get name;

  /// Produces an execution plan for the current run context.
  Future<AiPlan> plan(AiRunContext context);

  /// Produces the final structured output after plan execution.
  Future<Map<String, dynamic>> synthesize(AiRunContext context) async {
    return Map<String, dynamic>.from(context.state);
  }
}

/// Contract for turning a goal into a plan.
abstract class AiPlanner {
  Future<AiPlan> createPlan(AiAgent agent, AiRunContext context);
}

/// Default planner that delegates planning to the agent itself.
class DefaultAiPlanner implements AiPlanner {
  @override
  Future<AiPlan> createPlan(AiAgent agent, AiRunContext context) {
    return agent.plan(context);
  }
}

/// Contract for executing an AI plan.
abstract class AiExecutor {
  Future<AiRunResult> execute({
    required AiAgent agent,
    required AiRunContext context,
    required AiPlan plan,
    required AiToolRegistry toolRegistry,
    required AiToolPolicy toolPolicy,
  });
}

/// Default executor that runs plan steps sequentially.
class DefaultAiExecutor implements AiExecutor {
  @override
  Future<AiRunResult> execute({
    required AiAgent agent,
    required AiRunContext context,
    required AiPlan plan,
    required AiToolRegistry toolRegistry,
    required AiToolPolicy toolPolicy,
  }) async {
    try {
      context.run.status = AiRunStatus.running;
      await context.addEvent('run.started', payload: {
        'agent': agent.name,
        'plan': plan.toMap(),
      });

      for (final step in plan.steps) {
        await context.addEvent('step.started', payload: step.toMap());

        if (step.toolName != null && step.toolName!.isNotEmpty) {
          context.run.status = AiRunStatus.waitingForTool;

          final tool = toolRegistry.tool(step.toolName!);
          if (tool == null) {
            throw StateError('Unknown AI tool: ${step.toolName}');
          }

          final invocation = AiToolInvocation(
            name: step.toolName!,
            runId: context.run.id,
            userId: context.userId,
            tenantId: context.tenantId,
            arguments: step.arguments,
            enabledByDefault: tool.enabledByDefault,
            requiredCapabilities: tool.requiredCapabilities,
          );
          final allowed = await toolPolicy.canExecute(invocation);
          if (!allowed) {
            throw StateError('Tool execution forbidden for ${step.toolName}');
          }

          final result = await tool.execute(
            AiToolContext(
              runId: context.run.id,
              userId: context.userId,
              tenantId: context.tenantId,
              state: context.state,
              arguments: step.arguments,
              context: context.requestContext,
              metadata: context.metadata,
              artifacts: context.artifacts,
            ),
          );
          context.state[step.id] = result;
          context.run.status = AiRunStatus.running;
          await context.addEvent('step.tool.completed', payload: {
            'stepId': step.id,
            'tool': step.toolName,
            'result': result,
          });
        } else {
          context.state[step.id] = step.arguments;
          await context.addEvent('step.completed', payload: {
            'stepId': step.id,
            'result': step.arguments,
          });
        }
      }

      final output = await agent.synthesize(context);
      context.run.status = AiRunStatus.completed;
      context.run.output = output;
      await context.addEvent('run.completed', payload: {
        'output': output,
      });

      return AiRunResult(
        run: context.run,
        output: output,
      );
    } catch (error) {
      context.run.status = AiRunStatus.failed;
      await context.addEvent('run.failed', payload: {
        'error': error.toString(),
      });
      rethrow;
    }
  }
}

/// Generates a random run id for AI executions.
String generateAiRunId() {
  final random = Random.secure();
  final bytes = List<int>.generate(12, (_) => random.nextInt(256));
  return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}
