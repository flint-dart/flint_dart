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
        'Try /ai-demo/reporting and /ai-demo/content-email for real business agent examples.',
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

  Future<Response> reporting() async {
    _ensureDemoRuntimeConfigured();

    final run = await context.ai.run(
      agent: _ReportingAgent(),
      goal: const AiGoal(
        task: 'Build an operations report',
        input: {
          'period': 'this_week',
          'focus': 'support, projects, and AI tasks',
        },
      ),
      userId: 'demo-analyst',
      context: context,
    );

    return res.json({
      'ok': true,
      'report': run.toMap(),
      'events': await context.ai.loadRunEvents(run.run.id),
    });
  }

  Future<Response> contentEmail() async {
    _ensureDemoRuntimeConfigured();

    final body = await req.json();
    final run = await context.ai.run(
      agent: _ContentEmailAgent(),
      goal: AiGoal(
        task: 'Draft a product email',
        input: {
          'product': body['product'] ?? 'Flint Dart',
          'audience': body['audience'] ?? 'Dart developers',
          'goal': body['goal'] ?? 'invite them to try the AI runtime',
          'tone': body['tone'] ?? 'clear and practical',
        },
      ),
      userId: body['userId']?.toString() ?? 'demo-marketer',
      context: context,
    );

    return res.json({
      'ok': true,
      'draft': run.toMap(),
      'events': await context.ai.loadRunEvents(run.run.id),
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

    if (context.ai.tools.tool('example.operations_report') == null) {
      context.ai.registerTool(_OperationsReportTool());
    }

    if (context.ai.tools.tool('example.content_email') == null) {
      context.ai.registerTool(_ContentEmailDraftTool());
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
    final requestContext = context.requestContext;
    final supportsUppercaseTool = requestContext is Context &&
        requestContext.ai.tools.tool('example.uppercase') != null;

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
    final requestContext = context.requestContext;
    final ai = requestContext is Context ? requestContext.ai : null;
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

class _ReportingAgent extends AiAgent {
  @override
  String get name => 'operations_reporting_agent';

  @override
  Future<AiPlan> plan(AiRunContext context) async {
    return AiPlan(
      steps: [
        AiPlanStep(
          id: 'operations_report',
          type: 'tool',
          description: 'Create a structured operations report',
          toolName: 'example.operations_report',
          arguments: context.goal.input,
        ),
      ],
      metadata: const {'kind': 'reporting'},
    );
  }

  @override
  Future<Map<String, dynamic>> synthesize(AiRunContext context) async {
    final report = Map<String, dynamic>.from(
      context.state['operations_report'] as Map? ?? const {},
    );

    return {
      'title': report['title'],
      'summary': report['summary'],
      'metrics': report['metrics'],
      'recommendations': report['recommendations'],
    };
  }
}

class _ContentEmailAgent extends AiAgent {
  @override
  String get name => 'content_email_agent';

  @override
  Future<AiPlan> plan(AiRunContext context) async {
    return AiPlan(
      steps: [
        AiPlanStep(
          id: 'email_draft',
          type: 'tool',
          description: 'Draft a product email',
          toolName: 'example.content_email',
          arguments: context.goal.input,
        ),
      ],
      metadata: const {'kind': 'content_email'},
    );
  }

  @override
  Future<Map<String, dynamic>> synthesize(AiRunContext context) async {
    final draft = Map<String, dynamic>.from(
      context.state['email_draft'] as Map? ?? const {},
    );

    return {
      'subject': draft['subject'],
      'previewText': draft['previewText'],
      'body': draft['body'],
      'callToAction': draft['callToAction'],
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

class _OperationsReportTool extends AiTool {
  @override
  String get name => 'example.operations_report';

  @override
  String get description => 'Builds a demo operations report.';

  @override
  bool get enabledByDefault => true;

  @override
  Future<Map<String, dynamic>> execute(AiToolContext context) async {
    final period = context.arguments['period']?.toString() ?? 'current_period';
    final focus = context.arguments['focus']?.toString() ?? 'operations';
    final metrics = {
      'openSupportTickets': 12,
      'activeProjects': 7,
      'queuedAiTasks': 5,
      'pendingReviews': 3,
    };

    return {
      'title': 'Operations report for $period',
      'summary':
          'The $focus view shows support pressure is moderate while AI task throughput is healthy.',
      'metrics': metrics,
      'recommendations': [
        'Review high-priority support tickets first.',
        'Move queued AI tasks with customer impact to the top of the queue.',
        'Ask project owners to update stale delivery milestones.',
      ],
    };
  }
}

class _ContentEmailDraftTool extends AiTool {
  @override
  String get name => 'example.content_email';

  @override
  String get description => 'Drafts a practical product email.';

  @override
  bool get enabledByDefault => true;

  @override
  Future<Map<String, dynamic>> execute(AiToolContext context) async {
    final product = context.arguments['product']?.toString() ?? 'Flint Dart';
    final audience =
        context.arguments['audience']?.toString() ?? 'Dart developers';
    final goal = context.arguments['goal']?.toString() ?? 'try the product';
    final tone = context.arguments['tone']?.toString() ?? 'clear';

    return {
      'subject': '$product can help your next Dart build move faster',
      'previewText': 'A $tone note for $audience.',
      'body':
          'Hi,\n\n$product is built for $audience who want to $goal without stitching together too many tools.\n\nIt gives you routing, data, UI, and AI workflow building blocks in Dart, so the team can keep momentum inside one stack.\n\nBest,\nThe Flint Team',
      'callToAction': 'Start a small pilot with one real workflow.',
    };
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
