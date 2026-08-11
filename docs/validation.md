# Validation

Validation is implemented by `Validator` in `lib/src/validation/validator.dart` and exposed through `Request.validate()`.

## Request Validation

`Request.validate()` gathers input from query parameters, body/form fields, uploaded files, and route params. Precedence is:

```text
query < body/form fields < files < route params
```

Then it calls `Validator.validate(...)`.

```dart
Future<Response> store(Request req, Response res) async {
  final data = await req.validate({
    'title': 'required|string|min:3',
    'subTitle': 'required|string|min:3',
  });

  await PostModel().create(data);
  return res.status(201).json({'message': 'created'});
}
```

This is the same pattern used in `example/lib/controllers/post_controller.dart`.

## Supported Rules

The implementation supports:

- `required`
- `string`
- `int`
- `double`
- `bool`
- `email`
- `regex:<pattern>`
- `list`
- `list:string`
- `list:int`
- `list:double`
- `list:bool`
- `confirmed`
- `date`
- `in:a,b,c`
- `not_in:a,b,c`
- `min:<n>`
- `max:<n>`

`confirmed` accepts either `password_confirmation` or `confirm_password`.

```dart
await req.validate({
  'email': 'required|email',
  'password': 'required|string|min:8|confirmed',
});
```

## Custom Messages

Custom messages can be keyed by `field.rule`, `field`, or `rule`, in that order. Placeholders include `:field`, `:min`, `:max`, and `:value`.

```dart
await req.validate(
  {'email': 'required|email|min:5'},
  messages: {
    'email.required': 'Email is required.',
    'email.email': 'Enter a valid email address.',
    'min': ':field must be at least :min characters.',
  },
);
```

## Error Handling

`Validator.validate()` throws `ValidationException`, which stores:

```dart
final Map<String, List<String>> errors;
```

With the default `ExceptionMiddleware`, validation errors become JSON with status `422`.

## Important Limits

- Unknown input fields are rejected unless they are confirmation fields ending in `_confirmation` or starting with `confirm_`.
- Type checks are strict. For example, `int` requires a Dart `int`; the validator does not parse `"1"` into `1`.
- `regex:<pattern>` receives the substring after `regex:` directly. Patterns containing `|` conflict with the pipe-separated rule format.
- `Request.validateForm()` exists but is deprecated in favor of `validate()`.
