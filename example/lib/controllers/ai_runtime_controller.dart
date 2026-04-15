import 'package:flint_dart/flint_dart.dart';
import 'package:flint_dart/ai.dart';

class AiRuntimeController extends Controller {
  Future<Response> index() async {
    _ensureDemoRuntimeConfigured();

    return res.json({
      'message': 'AI runtime examples are available under /ai-demo/*',
      'providers': context.ai.providers.describeAll(),
      'tools': context.ai.tools.describeAll(),
      'workflows': context.ai.workflows.describeAll(),
      'notes': [
        'Visit /ai-demo/runtime, /ai-demo/workflow, /ai-demo/chat, or /ai-demo/support.',
        'Register OpenAI, Anthropic, or Gemini chat providers through app.ai.',
        'Configure persistent AI memory and repository stores for production.',
      ],
    });
  }

  Future<Response> runtime() async {
    _ensureDemoRuntimeConfigured();

    final run = await context.ai.run(
      agent: _ExampleAgent(),
      goal: const AiGoal(
        task: 'Prepare a support reply',
        input: {
          'message': 'please reset my password',
        },
      ),
      userId: 'demo-user',
      context: context,
    );

    return res.json({
      'ok': true,
      'agentRun': run.toMap(),
      'availableProviders': context.ai.providers.describeAll(),
      'availableTools': context.ai.tools.describeAll(),
      'availableWorkflows': context.ai.workflows.describeAll(),
    });
  }

  Future<Response> workflow() async {
    _ensureDemoRuntimeConfigured();

    final workflow = await context.ai.runWorkflow(
      'example_support_workflow',
      userId: 'demo-user',
      context: context,
      input: const {'ticket': 'T-100', 'summary': 'Password reset needed'},
    );

    return res.json({
      'ok': true,
      'workflow': workflow.toMap(),
    });
  }

  Future<Response> chat() async {
    _ensureDemoRuntimeConfigured();

    final result = await context.ai.chat(
      providerId: 'example-chat',
      request: const ChatRequest(
        model: 'example-model',
        messages: [
          ChatMessage(role: 'user', content: 'Say hello from the example AI'),
        ],
      ),
    );

    return res.json({
      'ok': true,
      'chat': result.toMap(),
    });
  }

  Future<Response> support() async {
    _ensureDemoRuntimeConfigured();

    final body = await req.json();
    final issue = body['issue']?.toString().trim() ?? '';
    if (issue.isEmpty) {
      return res.status(422).json({
        'ok': false,
        'message': 'issue is required',
      });
    }

    final threadId = body['threadId']?.toString() ?? 'demo-support-thread';
    final userId = body['userId']?.toString() ?? 'demo-user';
    final priority = body['priority']?.toString() ?? _inferPriority(issue);
    final channel = body['channel']?.toString() ?? 'email';

    final existingThread = await context.ai.loadThreadMessages(threadId);

    await context.ai.saveThreadMessage(threadId, {
      'role': 'user',
      'content': issue,
      'channel': channel,
    });

    final run = await context.ai.run(
      agent: _SupportAssistantAgent(),
      goal: AiGoal(
        task: 'Prepare a support response',
        input: {
          'issue': issue,
          'priority': priority,
          'channel': channel,
          'threadMessageCount': existingThread.length + 1,
        },
      ),
      userId: userId,
      threadId: threadId,
      context: context,
    );

    final workflow = await context.ai.runWorkflow(
      'example_support_workflow',
      userId: userId,
      threadId: threadId,
      context: context,
      metadata: const {'source': 'support-demo'},
      input: {
        'ticket': body['ticket'] ?? 'T-100',
        'summary': run.output['responseDraft'],
        'priority': priority,
      },
    );

    await context.ai.saveThreadMessage(threadId, {
      'role': 'assistant',
      'content': run.output['responseDraft'],
      'channel': channel,
      'summary': run.output['summary'],
      'workflowStatus': workflow.output['status'],
    });

    return res.json({
      'ok': true,
      'run': run.toMap(),
      'workflow': workflow.toMap(),
      'thread': await context.ai.loadThreadMessages(threadId),
      'events': await context.ai.loadRunEvents(run.run.id),
      'providers': context.ai.providers.describeAll(),
      'tools': context.ai.tools.describeAll(),
    });
  }

  void _ensureDemoRuntimeConfigured() {
    if (context.ai.providers.chatProvider('example-chat') == null) {
      context.ai.registerChatProvider(_ExampleChatProvider());
    }

    if (context.ai.tools.tool('example.uppercase') == null) {
      context.ai.registerTool(_UppercaseAiTool());
    }

    if (context.ai.tools.tool('example.ticket_summary') == null) {
      context.ai.registerTool(_TicketSummaryAiTool());
    }

    if (context.ai.workflows.workflow('example_support_workflow') == null) {
      context.ai.registerWorkflow(_ExampleSupportWorkflow());
    }
  }

  String _inferPriority(String issue) {
    final normalized = issue.toLowerCase();
    if (normalized.contains('urgent') ||
        normalized.contains('asap') ||
        normalized.contains('outage') ||
        normalized.contains('cannot login')) {
      return 'high';
    }
    return 'normal';
  }
}

class _ExampleAgent extends AiAgent {
  @override
  String get name => 'example_support_agent';

  @override
  Future<AiPlan> plan(AiRunContext context) async {
    final message = context.goal.input['message'] ?? context.goal.task;
    final supportsUppercaseTool =
        context.requestContext?.ai.tools.tool('example.uppercase') != null;

    return AiPlan(
      steps: [
        if (supportsUppercaseTool)
          AiPlanStep(
            id: 'normalize',
            type: 'tool',
            description: 'Normalize the support message',
            toolName: 'example.uppercase',
            arguments: {
              'text': message,
            },
          )
        else
          AiPlanStep(
            id: 'normalize',
            type: 'state',
            description: 'Normalize the support message',
            arguments: {
              'text': message.toString().trim().toUpperCase(),
            },
          ),
      ],
      metadata: const {'kind': 'example'},
    );
  }

  @override
  Future<Map<String, dynamic>> synthesize(AiRunContext context) async {
    return {
      'goal': context.goal.toMap(),
      'normalizedMessage': (context.state['normalize'] as Map?)?['text'],
      'events': context.run.events.map((event) => event.toMap()).toList(),
    };
  }
}

class _SupportAssistantAgent extends AiAgent {
  @override
  String get name => 'support_assistant_agent';

  @override
  Future<AiPlan> plan(AiRunContext context) async {
    final ai = context.requestContext?.ai;
    final supportsSummaryTool =
        ai?.tools.tool('example.ticket_summary') != null;
    final supportsUppercaseTool = ai?.tools.tool('example.uppercase') != null;
    final issue = context.goal.input['issue']?.toString() ?? '';
    final priority = context.goal.input['priority']?.toString() ?? 'normal';
    final channel = context.goal.input['channel']?.toString() ?? 'email';

    return AiPlan(
      steps: [
        if (supportsSummaryTool)
          AiPlanStep(
            id: 'summarize_ticket',
            type: 'tool',
            description: 'Build the support summary',
            toolName: 'example.ticket_summary',
            arguments: {
              'issue': issue,
              'priority': priority,
              'channel': channel,
            },
          )
        else
          AiPlanStep(
            id: 'summarize_ticket',
            type: 'state',
            description: 'Build the support summary',
            arguments: _TicketSummaryAiTool.buildSummary(
              issue: issue,
              priority: priority,
              channel: channel,
            ),
          ),
        if (supportsUppercaseTool)
          AiPlanStep(
            id: 'normalize_tone',
            type: 'tool',
            description: 'Normalize the tone for the customer draft',
            toolName: 'example.uppercase',
            arguments: {
              'text': issue,
            },
          )
        else
          AiPlanStep(
            id: 'normalize_tone',
            type: 'state',
            description: 'Normalize the tone for the customer draft',
            arguments: {
              'text': issue.trim().toUpperCase(),
            },
          ),
      ],
      metadata: const {'kind': 'support'},
    );
  }

  @override
  Future<Map<String, dynamic>> synthesize(AiRunContext context) async {
    final summary = Map<String, dynamic>.from(
      context.state['summarize_ticket'] as Map? ?? const {},
    );
    final normalized = Map<String, dynamic>.from(
      context.state['normalize_tone'] as Map? ?? const {},
    );

    return {
      'summary': summary['summary'],
      'responseDraft': summary['draft'],
      'recommendedActions': summary['actions'],
      'normalizedIssue': normalized['text'],
      'threadMessageCount': context.goal.input['threadMessageCount'],
      'events': context.run.events.map((event) => event.toMap()).toList(),
    };
  }
}

class _UppercaseAiTool extends AiTool {
  @override
  String get name => 'example.uppercase';

  @override
  String get description => 'Normalizes text for the example AI runtime.';

  @override
  bool get enabledByDefault => true;

  @override
  Future<Map<String, dynamic>> execute(AiToolContext context) async {
    final text = context.arguments['text']?.toString() ?? '';
    return {
      'text': text.trim().toUpperCase(),
      'length': text.trim().length,
    };
  }
}

class _TicketSummaryAiTool extends AiTool {
  @override
  String get name => 'example.ticket_summary';

  @override
  String get description => 'Builds a structured support summary and draft.';

  @override
  bool get enabledByDefault => true;

  @override
  Future<Map<String, dynamic>> execute(AiToolContext context) async {
    return buildSummary(
      issue: context.arguments['issue']?.toString() ?? '',
      priority: context.arguments['priority']?.toString() ?? 'normal',
      channel: context.arguments['channel']?.toString() ?? 'email',
    );
  }

  static Map<String, dynamic> buildSummary({
    required String issue,
    required String priority,
    required String channel,
  }) {
    final normalizedIssue = issue.trim();
    final category = _categorizeIssue(normalizedIssue);
    final actions = _actionsForCategory(category);

    return {
      'category': category,
      'summary': '[$priority][$channel][$category] $normalizedIssue',
      'draft':
          'We received your $category request and are reviewing it with $priority priority. '
              'Next steps: ${actions.join(', ')}.',
      'actions': actions,
    };
  }

  static String _categorizeIssue(String issue) {
    final normalized = issue.toLowerCase();
    if (normalized.contains('password') || normalized.contains('reset')) {
      return 'account_access';
    }
    if (normalized.contains('billing') || normalized.contains('refund')) {
      return 'billing';
    }
    if (normalized.contains('bug') || normalized.contains('error')) {
      return 'technical_issue';
    }
    return 'general_support';
  }

  static List<String> _actionsForCategory(String category) {
    switch (category) {
      case 'account_access':
        return const [
          'verify account ownership',
          'send reset instructions',
          'confirm successful login',
        ];
      case 'billing':
        return const [
          'review the invoice',
          'check payment status',
          'confirm the resolution',
        ];
      case 'technical_issue':
        return const [
          'collect reproduction details',
          'review recent errors',
          'share a workaround if available',
        ];
      default:
        return const [
          'gather missing details',
          'route to the correct queue',
          'follow up with the customer',
        ];
    }
  }
}

class _ExampleSupportWorkflow extends AiWorkflow {
  @override
  String get name => 'example_support_workflow';

  @override
  String get description => 'Creates a lightweight support workflow result.';

  @override
  Future<Map<String, dynamic>> run(AiWorkflowContext context) async {
    final priority = context.input['priority']?.toString() ?? 'normal';
    return {
      'ticket': context.input['ticket']?.toString() ?? 'T-100',
      'summary': context.input['summary'],
      'priority': priority,
      'status': priority == 'high' ? 'expedited' : 'queued',
      'source': context.metadata['source'] ?? 'example',
      'hasRequestContext': context.requestContext != null,
    };
  }
}

class _ExampleChatProvider extends ChatProvider {
  @override
  String get id => 'example-chat';

  @override
  String get displayName => 'Example Chat Provider';

  @override
  Future<ChatResult> complete(ChatRequest request) async {
    final lastMessage = request.messages.isEmpty
        ? 'Hello from the example AI'
        : request.messages.last.content;

    return ChatResult(
      providerId: id,
      model: request.model,
      content: 'Example AI response: $lastMessage',
      usage: ChatUsage(
        inputTokens:
            lastMessage.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).length,
        outputTokens: 5,
        totalTokens: lastMessage
                .split(RegExp(r'\s+'))
                .where((t) => t.isNotEmpty)
                .length +
            5,
      ),
      raw: {
        'echo': true,
      },
    );
  }
}
