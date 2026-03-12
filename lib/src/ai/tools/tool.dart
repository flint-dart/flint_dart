import 'package:flint_dart/src/context.dart';

/// Authorization request describing a planned tool call.
class AiToolInvocation {
  final String name;
  final String runId;
  final String? userId;
  final String? tenantId;
  final Map<String, dynamic> arguments;
  final bool enabledByDefault;
  final Set<String> requiredCapabilities;

  const AiToolInvocation({
    required this.name,
    required this.runId,
    required this.arguments,
    this.userId,
    this.tenantId,
    this.enabledByDefault = false,
    this.requiredCapabilities = const {},
  });
}

/// Contract for authorizing tool execution.
abstract class AiToolPolicy {
  Future<bool> canExecute(AiToolInvocation invocation);
}

/// Permissive tool policy intended only for explicit opt-in use.
class AllowAllAiToolPolicy implements AiToolPolicy {
  @override
  Future<bool> canExecute(AiToolInvocation invocation) async => true;
}

/// Tool policy that rejects every tool invocation.
class DenyAllAiToolPolicy implements AiToolPolicy {
  @override
  Future<bool> canExecute(AiToolInvocation invocation) async => false;
}

/// Safe default policy that only allows explicitly approved tools.
class SafeDefaultAiToolPolicy implements AiToolPolicy {
  final Set<String> allowedTools;
  final bool requireUserBinding;

  const SafeDefaultAiToolPolicy({
    this.allowedTools = const {},
    this.requireUserBinding = false,
  });

  @override
  Future<bool> canExecute(AiToolInvocation invocation) async {
    if (requireUserBinding && invocation.userId == null) {
      return false;
    }
    if (allowedTools.contains(invocation.name)) {
      return true;
    }
    return invocation.enabledByDefault;
  }
}

/// Context passed into tool execution.
class AiToolContext {
  final String runId;
  final String? userId;
  final String? tenantId;
  final Map<String, dynamic> state;
  final Map<String, dynamic> arguments;
  final Context? context;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> artifacts;

  const AiToolContext({
    required this.runId,
    required this.state,
    required this.arguments,
    this.userId,
    this.tenantId,
    this.context,
    this.metadata = const {},
    this.artifacts = const {},
  });
}

/// Contract implemented by executable AI tools.
abstract class AiTool {
  /// Stable tool name used in plans and policies.
  String get name;
  /// Human-readable tool description.
  String get description;
  /// Whether the tool is allowed by the safe default policy.
  bool get enabledByDefault => false;
  /// Named capabilities required by this tool.
  Set<String> get requiredCapabilities => const {};

  /// Executes the tool call for the supplied context.
  Future<Map<String, dynamic>> execute(AiToolContext context);

  /// Returns a serializable description of the tool.
  Map<String, dynamic> describe() => {
        'name': name,
        'description': description,
        'enabledByDefault': enabledByDefault,
        'requiredCapabilities': requiredCapabilities.toList(),
      };
}

/// Registry for executable AI tools.
class AiToolRegistry {
  final Map<String, AiTool> _tools = {};

  /// Registers a tool by name.
  void register(AiTool tool) {
    _tools[tool.name] = tool;
  }

  /// Looks up a tool by name.
  AiTool? tool(String name) => _tools[name];

  /// Returns descriptions for all registered tools.
  List<Map<String, dynamic>> describeAll() {
    return _tools.values.map((tool) => tool.describe()).toList();
  }
}
