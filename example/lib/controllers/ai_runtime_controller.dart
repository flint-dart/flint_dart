import 'package:flint_dart/flint_dart.dart';

class AiRuntimeController extends Controller {
  Future<Response> index() async {
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
    final body = await req.json();
    final issue = body['issue']?.toString() ?? 'password reset request';
    final threadId = body['threadId']?.toString() ?? 'demo-support-thread';
    final userId = body['userId']?.toString() ?? 'demo-user';

    await context.ai.saveThreadMessage(threadId, {
      'role': 'user',
      'content': issue,
      'channel': body['channel'] ?? 'email',
    });

    final run = await context.ai.run(
      agent: _SupportAssistantAgent(),
      goal: AiGoal(
        task: 'Prepare a support response',
        input: {
          'issue': issue,
          'priority': body['priority'] ?? 'normal',
          'channel': body['channel'] ?? 'email',
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
        'priority': body['priority'] ?? 'normal',
      },
    );

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
}

class _ExampleAgent extends AiAgent {
  @override
  String get name => 'example_support_agent';

  @override
  Future<AiPlan> plan(AiRunContext context) async {
    return AiPlan(
      steps: [
        AiPlanStep(
          id: 'normalize',
          type: 'tool',
          description: 'Normalize the support message',
          toolName: 'example.uppercase',
          arguments: {
            'text': context.goal.input['message'] ?? context.goal.task,
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
    return AiPlan(
      steps: [
        AiPlanStep(
          id: 'summarize_ticket',
          type: 'tool',
          description: 'Build the support summary',
          toolName: 'example.ticket_summary',
          arguments: {
            'issue': context.goal.input['issue'],
            'priority': context.goal.input['priority'],
            'channel': context.goal.input['channel'],
          },
        ),
        AiPlanStep(
          id: 'normalize_tone',
          type: 'tool',
          description: 'Normalize the tone for the customer draft',
          toolName: 'example.uppercase',
          arguments: {
            'text': context.goal.input['issue'],
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
      'normalizedIssue': normalized['text'],
      'events': context.run.events.map((event) => event.toMap()).toList(),
    };
  }
}
