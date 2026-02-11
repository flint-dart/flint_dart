import 'package:flint_dart/flint_dart.dart';

class ValidationMiddleware extends Middleware {
  final Map<String, String> rules;

  ValidationMiddleware(this.rules);

  @override
  Handler handle(Handler next) {
    return (Context context) async {
      try {
        final data = await context.req.json();
        await Validator.validate(
          data,
          {
            "email": "required|email",
            "password": "required|string|min:8|confirmed",
          },
          messages: {
            "email.required": "Email is required.",
            "email.email": "Please provide a valid email address.",
            "password.required": "Password is required.",
            "password.min": "Password must be at least :min characters.",
            "confirmed": "The :field confirmation does not match.",
          },
        );
        return await next(context);
      } catch (e) {
        return context.res?.status(400).json({'error': e.toString()});
      }
    };
  }
}
