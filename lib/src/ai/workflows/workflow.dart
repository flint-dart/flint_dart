import 'package:flint_dart/src/context.dart';

/// Execution context passed into a workflow.
class AiWorkflowContext {
  final String? userId;
  final String? tenantId;
  final String? threadId;
  final Map<String, dynamic> input;
  final Context? requestContext;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> artifacts;
  final String? runId;
  final bool isBackground;

  const AiWorkflowContext({
    this.userId,
    this.tenantId,
    this.threadId,
    this.input = const {},
    this.requestContext,
    this.metadata = const {},
    this.artifacts = const {},
    this.runId,
    this.isBackground = false,
  });
}

/// Contract for named reusable AI workflows.
abstract class AiWorkflow {
  /// Stable workflow name used for registration and lookup.
  String get name;
  /// Human-readable description of the workflow.
  String get description;

  /// Executes the workflow and returns a structured result.
  Future<Map<String, dynamic>> run(AiWorkflowContext context);

  /// Returns a serializable description of the workflow.
  Map<String, dynamic> describe() => {
        'name': name,
        'description': description,
      };
}

/// Registry for named workflows.
class AiWorkflowRegistry {
  final Map<String, AiWorkflow> _workflows = {};

  /// Registers a workflow by name.
  void register(AiWorkflow workflow) {
    _workflows[workflow.name] = workflow;
  }

  /// Looks up a workflow by name.
  AiWorkflow? workflow(String name) => _workflows[name];

  /// Returns descriptions for all registered workflows.
  List<Map<String, dynamic>> describeAll() {
    return _workflows.values.map((workflow) => workflow.describe()).toList();
  }
}

/// Result wrapper returned by [FlintAi.runWorkflow].
class AiWorkflowRunResult {
  final String workflowName;
  final Map<String, dynamic> output;

  const AiWorkflowRunResult({
    required this.workflowName,
    required this.output,
  });

  /// Serializes the workflow result into a map.
  Map<String, dynamic> toMap() => {
        'workflowName': workflowName,
        'output': output,
      };
}
