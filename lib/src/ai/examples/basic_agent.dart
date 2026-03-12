import 'package:flint_dart/src/ai/runtime/runtime.dart';

/// Minimal example agent that copies the incoming goal into run state.
class BasicTaskAgent extends AiAgent {
  @override
  final String name;

  BasicTaskAgent({
    this.name = 'basic_task_agent',
  });

  @override
  Future<AiPlan> plan(AiRunContext context) async {
    return AiPlan(
      steps: [
        AiPlanStep(
          id: 'capture_goal',
          type: 'state',
          description: 'Capture the incoming goal as run state.',
          arguments: {
            'task': context.goal.task,
            'input': context.goal.input,
          },
        ),
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> synthesize(AiRunContext context) async {
    return {
      'task': context.goal.task,
      'state': context.state,
    };
  }
}
