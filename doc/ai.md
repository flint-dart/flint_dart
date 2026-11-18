# AI Helpers

Flint exposes AI helpers through:

```dart
import 'package:flint_dart/ai.dart';
```

That entrypoint exports the `flint_ai` runtime plus Flint Dart adapters for
environment configuration, database-backed memory, database-backed run, thread,
trace, and artifact persistence, and the canonical AI table definitions.

Use this guide before adding AI chat, agents, tools, workflows, memory, or
persistence to an app.

## Files To Inspect First

Before changing AI behavior, inspect:

- `lib/main.dart` for the `Flint(...)` app and boot configuration.
- `lib/config/table_registry.dart` for `...flintAiTables`.
- `lib/config/ai.dart` or the app's equivalent AI boot file, when present.
- `lib/ai/agents/` for `AiAgent` classes.
- `lib/ai/tools/` for `AiTool` classes and tool capability names.
- `lib/ai/workflows/` for `AiWorkflow` classes.
- `lib/jobs/` when AI work runs in a background worker.
- `lib/middlewares/` and `docs/authentication.md` before binding AI runs to a
  user, role, or tenant.
- `docs/models-and-database.md` before changing AI tables or migrations.
- `docs/jobs-and-workers.md` before moving AI work into durable background jobs.
- `docs/logging.md` before logging AI run or provider failures.

## Import Rules

Use `package:flint_dart/ai.dart` when code names AI types:

```dart
import 'package:flint_dart/ai.dart';
```

Use `package:flint_dart/flint_dart.dart` for app, routing, controllers,
middleware, request, response, database, logging, jobs, and server utilities:

```dart
import 'package:flint_dart/flint_dart.dart';
```

Do not import AI provider secrets or AI runtime code into `lib/ui`. Browser UI
should call server endpoints; providers and API keys belong on the server.

## Runtime Overview

`FlintAi` is the main runtime object. A runtime owns:

- `providers`: registered chat, image, and embedding providers.
- `tools`: registered executable `AiTool` objects.
- `workflows`: registered named `AiWorkflow` objects.
- `memoryStore`: run-event and thread-message memory.
- `repository`: durable run, thread, trace, and artifact stores.
- `planner`: turns an `AiGoal` into an `AiPlan`.
- `executor`: runs plan steps and records state/events.
- `toolPolicy`: decides whether a planned tool call may execute.

The `Flint` app creates one AI runtime:

```dart
final app = Flint();

app.ai; // FlintAi
```

For HTTP and WebSocket handlers, Flint writes that same runtime into
`Context`, so route handlers and controllers can use:

```dart
ctx.ai;
context.ai;
```

Do not create a new `FlintAi()` inside every request. Configure `app.ai` once
during boot, then use `ctx.ai` or controller `context.ai` inside request code.

## App Wiring

Create a small boot file for AI configuration.

File: `lib/config/ai.dart`

```dart
import 'package:flint_dart/ai.dart';
import 'package:flint_dart/flint_dart.dart';

import '../ai/agents/ticket_triage_agent.dart';
import '../ai/tools/ticket_summary_tool.dart';
import '../ai/workflows/support_reply_workflow.dart';

void configureAi(Flint app) {
  app.ai.useChatProvidersFromEnv();
  app.ai.useProductionToolPolicyFromEnv();

  app.ai.registerTool(TicketSummaryTool());
  app.ai.registerWorkflow(SupportReplyWorkflow());
}
```

Call it once from `lib/main.dart`:

```dart
import 'package:flint_dart/flint_dart.dart';

import 'config/ai.dart';
import 'routes/ai_routes.dart';

void main(List<String> args) {
  final app = Flint(
    autoConnectDb: true,
    enableSwaggerDocs: true,
  );

  configureAi(app);

  app.routes(AiRoutes());
  app.listen(port: 3000, hotReload: true);
}
```

The agent, tool, workflow, route group, controller, and boot function each live
in their own file. Do not hide AI setup or business behavior inside private
methods on `main.dart` or a controller.

## Environment Providers

`useChatProvidersFromEnv()` registers every supported provider with credentials
present in `.env`.

Supported keys:

```text
OPENAI_API_KEY=
OPENAI_BEARER_TOKEN=
OPENAI_CHAT_ENDPOINT=

GEMINI_API_KEY=
GEMINI_BEARER_TOKEN=
GEMINI_CHAT_ENDPOINT=

ANTHROPIC_API_KEY=
ANTHROPIC_CHAT_ENDPOINT=
```

Registered chat provider ids:

- `openai`
- `gemini`
- `anthropic`

You can also register providers manually:

```dart
app.ai.registerChatProvider(
  OpenAiChatProvider(apiKey: FlintEnv.get('OPENAI_API_KEY')),
);
```

Use `ChatRequest` and `ChatMessage` for direct chat:

```dart
final result = await ctx.ai.chat(
  providerId: 'openai',
  request: const ChatRequest(
    model: 'gpt-4o-mini',
    messages: [
      ChatMessage(
        role: 'system',
        content: 'Answer with concise support guidance.',
      ),
      ChatMessage(
        role: 'user',
        content: 'How do I reset my password?',
      ),
    ],
    temperature: 0.2,
  ),
);

return ctx.res?.json({'answer': result.content});
```

For streaming:

```dart
await for (final event in ctx.ai.streamChat(
  providerId: 'openai',
  request: const ChatRequest(
    model: 'gpt-4o-mini',
    messages: [
      ChatMessage(role: 'user', content: 'Draft a reply'),
    ],
  ),
)) {
  if (event.type == 'chat.delta') {
    // Send the chunk to a WebSocket, SSE response, or local buffer.
  }
}
```

Providers emit `chat.delta` events for incremental text and `chat.completed`
when the final response is available. Provider failures are normalized as
`AiProviderException`.

## Database-Backed AI Tables

Flint Dart includes canonical table definitions for AI persistence:

- `ai_runs`: latest snapshot for each run.
- `ai_threads`: thread snapshots for custom thread persistence.
- `ai_traces`: run trace events for observability.
- `ai_artifacts`: generated artifacts attached to runs.
- `ai_run_events`: chronological run events loaded by `loadRunEvents(...)`.
- `ai_thread_messages`: chronological thread messages loaded by
  `loadThreadMessages(...)`.

Register the tables in `lib/config/table_registry.dart`:

```dart
import 'dart:isolate';

import 'package:flint_dart/ai.dart' show flintAiTables;
import 'package:flint_dart/schema.dart';

import '../models/user.dart';

void main(dynamic data, SendPort? sendPort) {
  runTableRegistry([
    ...flintAiTables,
    User().table,
  ], data, sendPort);
}
```

Then run migrations:

```bash
dart run flint_dart:flint migrate --no-interaction
```

When the database is connected and these tables exist, Flint's default app AI
runtime uses DB-backed stores. When the database is not connected, or the DB
store cannot be used, Flint logs a warning and falls back to in-memory storage.

In-memory fallback is useful during tests and early development. It is not
durable. Production apps that need audit history, resumable runs, thread
messages, or artifacts should register `...flintAiTables`, migrate the database,
and keep the database connected in the process that executes AI work.

## Memory Stores

`AiMemoryStore` stores:

- run events by `runId`
- thread messages by `threadId`

The public helpers are:

```dart
await app.ai.saveThreadMessage('ticket:T-100', {
  'role': 'user',
  'content': 'I cannot log in.',
});

final messages = await app.ai.loadThreadMessages('ticket:T-100');
final events = await app.ai.loadRunEvents(runId);
```

Flint Dart implementations:

- `FlintDbAiMemoryStore`: writes to `ai_run_events` and
  `ai_thread_messages`.
- `FlintAutoAiMemoryStore`: uses `FlintDbAiMemoryStore` when possible and
  falls back to `InMemoryAiMemoryStore`.
- `InMemoryAiMemoryStore`: development/test store from `flint_ai`.

Thread messages are not saved automatically by direct `chat(...)` calls. Save
the user message and assistant message yourself when you want conversation
history.

## Run, Thread, Trace, And Artifact Persistence

`AiRepository` groups the durable stores used by the runtime:

- `AiRunStore`: saves and loads run snapshots.
- `AiThreadStore`: saves and loads whole thread snapshots.
- `AiTraceStore`: appends run trace events.
- `AiArtifactStore`: saves artifacts produced during a run.

Flint Dart DB implementations:

- `FlintDbAiRunStore`
- `FlintDbAiThreadStore`
- `FlintDbAiTraceStore`
- `FlintDbAiArtifactStore`
- `FlintAutoAiRepository`

The `Flint` app uses:

```dart
FlintAi(
  memoryStore: FlintAutoAiMemoryStore(),
  repository: FlintAutoAiRepository(),
)
```

During `run(...)`, the runtime persists:

- the run when planning starts
- run events into the memory store
- trace events into the repository
- the run again as state and status change
- the final completed or failed run snapshot

Use artifacts for structured outputs that should survive beyond the response,
such as report JSON, generated draft metadata, analysis summaries, or references
to files saved through `Storage`.

Do not store large binary payloads directly in `ai_artifacts`. Save large files
with `Storage` or an external object store, then persist the path, checksum,
kind, and metadata as the artifact.

## Agents

An `AiAgent` turns a goal into a plan and synthesizes final output.

File: `lib/ai/agents/ticket_triage_agent.dart`

```dart
import 'package:flint_dart/ai.dart';

class TicketTriageAgent extends AiAgent {
  @override
  String get name => 'ticket_triage';

  @override
  Future<AiPlan> plan(AiRunContext context) async {
    return AiPlan(
      steps: [
        AiPlanStep(
          id: 'summary',
          type: 'tool',
          description: 'Summarize the ticket and suggest next actions.',
          toolName: 'tickets.summarize',
          arguments: {
            'ticketId': context.goal.input['ticketId'],
          },
        ),
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> synthesize(AiRunContext context) async {
    final summary = Map<String, dynamic>.from(
      context.state['summary'] as Map? ?? const {},
    );

    final output = {
      'ticketId': context.goal.input['ticketId'],
      'summary': summary['summary'],
      'nextActions': summary['nextActions'] ?? const [],
    };

    await context.saveArtifact('ticket_triage', {
      'ticketId': output['ticketId'],
      'output': output,
    });

    return output;
  }
}
```

Plan steps with a `toolName` call a registered tool after policy checks. Steps
without a `toolName` record their `arguments` directly into run state under the
step `id`.

## Tools

Tools are the controlled side-effect layer. Put anything that reads data, writes
data, sends messages, provisions resources, or calls external services inside
an `AiTool` so `AiToolPolicy` can authorize it.

File: `lib/ai/tools/ticket_summary_tool.dart`

```dart
import 'package:flint_dart/ai.dart';

class TicketSummaryTool extends AiTool {
  @override
  String get name => 'tickets.summarize';

  @override
  String get description => 'Summarizes a support ticket for triage.';

  @override
  Set<String> get requiredCapabilities => const {'tickets:read'};

  @override
  Future<Map<String, dynamic>> execute(AiToolContext context) async {
    final ticketId = context.arguments['ticketId']?.toString();
    if (ticketId == null || ticketId.isEmpty) {
      throw ArgumentError('ticketId is required.');
    }

    return {
      'ticketId': ticketId,
      'summary': 'Ticket $ticketId needs support review.',
      'nextActions': [
        'confirm account ownership',
        'review recent login failures',
        'reply with the safest reset path',
      ],
      'userId': context.userId,
      'tenantId': context.tenantId,
    };
  }
}
```

Keep `enabledByDefault` as `false` for destructive, externally visible, or
tenant-sensitive tools. Use precise `requiredCapabilities` such as
`tickets:read`, `tickets:write`, `billing:refund`, or `content:publish`.

`AiToolContext` exposes:

- `runId`
- `userId`
- `tenantId`
- mutable run `state`
- plan `arguments`
- the request `context` passed to `run(...)`
- policy and request `metadata`
- an in-memory `artifacts` map for the current run

Tool return values should be JSON-like maps because they are saved into run
state and run events.

## Running An Agent From A Controller

File: `lib/controllers/ai_controller.dart`

```dart
import 'package:flint_dart/ai.dart';
import 'package:flint_dart/flint_dart.dart';

import '../ai/agents/ticket_triage_agent.dart';

class AiController extends Controller {
  Future<Response> triageTicket() async {
    final data = await req.validate({
      'id': 'required|string',
    });

    final loadedUser = await req.user;
    if (loadedUser == null) {
      return res.status(401).json({'message': 'Unauthorized'});
    }

    final user = req.requireUser();
    final ticketId = data['id'].toString();

    final result = await context.ai.run(
      agent: TicketTriageAgent(),
      goal: AiGoal(
        task: 'Triage support ticket',
        input: {'ticketId': ticketId},
      ),
      userId: user['id']?.toString(),
      tenantId: user['tenantId']?.toString(),
      threadId: 'ticket:$ticketId',
      context: context,
      metadata: {
        'role': user['role'],
        'capabilities': user['capabilities'] ?? const ['tickets:read'],
      },
    );

    await context.ai.saveThreadMessage('ticket:$ticketId', {
      'role': 'assistant',
      'content': result.output['summary'],
      'runId': result.run.id,
    });

    return res.json({'data': result.toMap()});
  }
}
```

File: `lib/routes/ai_routes.dart`

```dart
import 'package:flint_dart/flint_dart.dart';

import '../controllers/ai_controller.dart';

class AiRoutes extends RouteGroup {
  @override
  String get prefix => '/ai';

  @override
  String get tag => 'AI';

  @override
  void register(Flint app) {
    final ai = app.controller(AiController.new);

    ai.post('/tickets/:id/triage', (controller) => controller.triageTicket());
  }
}
```

Use route middleware for normal auth checks in a real app. The controller above
also shows the lower-level `await req.user` and `req.requireUser()` pattern so
the run has a user id and metadata for tool policy.

## Workflows

Use `AiWorkflow` for named reusable AI-adjacent operations that do not need
agent planning. Workflows are useful for fixed pipelines, post-processing,
classification, report formatting, or safe deterministic work.

File: `lib/ai/workflows/support_reply_workflow.dart`

```dart
import 'package:flint_dart/ai.dart';

class SupportReplyWorkflow extends AiWorkflow {
  @override
  String get name => 'support.reply';

  @override
  String get description => 'Creates a support reply payload.';

  @override
  Future<Map<String, dynamic>> run(AiWorkflowContext context) async {
    return {
      'ticketId': context.input['ticketId'],
      'subject': 'We are reviewing your request',
      'body': context.input['summary'],
      'userId': context.userId,
      'threadId': context.threadId,
      'source': context.metadata['source'],
    };
  }
}
```

Run it from a controller, job, or service:

```dart
final workflow = await context.ai.runWorkflow(
  'support.reply',
  userId: user['id']?.toString(),
  threadId: 'ticket:$ticketId',
  context: context,
  metadata: const {'source': 'ticket-triage'},
  input: {
    'ticketId': ticketId,
    'summary': result.output['summary'],
  },
);
```

`runWorkflow(...)` returns `AiWorkflowRunResult`. It does not run the agent
planner and does not automatically become a durable queue job. Use `QueueJob`
when work must survive process restarts, retries, or worker scheduling.

## Tool Policy

The default `FlintAi()` policy is `SafeDefaultAiToolPolicy`. It allows:

- tools explicitly listed in `allowedTools`
- tools whose required capabilities are present on the user or policy
- tools with `enabledByDefault == true` when `allowEnabledByDefault` is true

Production apps should use `ProductionAiToolPolicy`, usually through env:

```dart
app.ai.useProductionToolPolicyFromEnv();
```

Supported env keys:

```text
AI_ALLOWED_TOOLS=tickets.summarize,reports.export
AI_ALLOWED_CAPABILITIES=tickets:read,reports:write
AI_ALLOWED_ROLES=ADMIN,OWNER
```

`ProductionAiToolPolicy` requires a bound user by default and does not honor
`enabledByDefault` unless explicitly configured to do so. Pass `userId`,
`tenantId`, roles, and capabilities when running agents:

```dart
final result = await context.ai.run(
  agent: TicketTriageAgent(),
  goal: AiGoal(task: 'Triage ticket', input: {'ticketId': ticketId}),
  userId: user['id']?.toString(),
  tenantId: user['tenantId']?.toString(),
  context: context,
  metadata: {
    'roles': user['roles'] ?? const [],
    'capabilities': user['capabilities'] ?? const [],
  },
);
```

Never allow destructive tools only because the prompt asks for them. The policy
must be able to decide from authenticated user, tenant, role, capability, and
tool name.

## Background AI Work

AI runs can be slow. Use a `QueueJob` when the work should continue outside the
HTTP request, be retried, or run from a worker process.

Important:

- configure AI providers in the worker process too
- register the same tools and workflows in the worker process
- include `...flintAiTables` and run migrations before workers start
- pass `userId`, `tenantId`, `threadId`, and metadata into the queued job
- use `Log.*` instead of `print(...)`

Read `docs/jobs-and-workers.md` before creating durable AI jobs.

## Security And Privacy

- Do not put provider API keys in browser UI, public config, generated bundles,
  or logs.
- Do not log raw prompts, raw provider responses, tokens, passwords, OTPs,
  authorization headers, cookies, or secret model inputs.
- Validate request input before building `AiGoal.input`.
- Bind runs to `userId` and `tenantId` whenever AI work affects user data.
- Keep tool capabilities narrow and action-specific.
- Use policies for tool execution, not prompt instructions.
- Store only metadata for large artifacts; save files through `Storage`.
- Review `ai_traces`, `ai_runs`, and `ai_artifacts` retention rules before
  storing sensitive user data.

## Common Mistakes

- Creating a new `FlintAi()` inside a controller instead of using `context.ai`.
- Registering providers and tools inside every request.
- Forgetting `...flintAiTables` before expecting durable AI persistence.
- Assuming direct `chat(...)` automatically saves thread history.
- Running production tools with no `userId`, role, tenant, or capabilities.
- Marking destructive tools as `enabledByDefault`.
- Storing large binary files directly in artifacts.
- Putting multiple agents, tools, workflows, or helpers in one Dart file.
- Importing `package:flint_dart/ai.dart` from browser UI files.

## Review Checklist

When reviewing AI code:

1. Read `docs/ai.md`, `docs/authentication.md`, `docs/models-and-database.md`,
   `docs/jobs-and-workers.md`, and `docs/logging.md` as needed.
2. Confirm the app configures `app.ai` once during boot.
3. Confirm AI tables are registered and migrated when persistence matters.
4. Confirm agents, tools, workflows, and routes each have their own file.
5. Confirm tools declare stable names, descriptions, and capabilities.
6. Confirm production tool policy cannot execute sensitive tools anonymously.
7. Confirm runs pass `userId`, `tenantId`, `threadId`, and metadata when needed.
8. Confirm thread messages are explicitly saved when conversation memory matters.
9. Confirm artifacts store structured metadata, not large raw files.
10. Confirm logs do not expose prompts, secrets, credentials, cookies, or tokens.
