import 'package:flint_dart/exception.dart';
import 'package:flint_dart/src/validation/validator.dart';
import 'package:test/test.dart';

void main() {
  group('Validator', () {
    test('accepts valid payload with mixed rules', () async {
      final data = <String, dynamic>{
        'name': 'Alice',
        'age': 25,
        'score': 10.5,
        'active': true,
        'email': 'alice@example.com',
        'tags': ['a', 'b'],
        'status': 'open',
        'startDate': '2026-02-10',
      };

      final rules = <String, String>{
        'name': 'required|string|min:3|max:20',
        'age': 'required|int|min:18|max:99',
        'score': 'double|min:1|max:100',
        'active': 'bool',
        'email': 'required|email',
        'tags': 'list:string|min:1',
        'status': 'in:open,closed,pending|not_in:archived',
        'startDate': 'date',
      };

      await Validator.validate(data, rules);
    });

    test('rejects unknown fields not defined in rules', () async {
      final data = <String, dynamic>{
        'name': 'Alice',
        'extra': 'not-allowed',
      };

      final rules = <String, String>{
        'name': 'required|string',
      };

      expect(
        () => Validator.validate(data, rules),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors['extra']?.first,
            'extra field error',
            contains('not allowed'),
          ),
        ),
      );
    });

    test('supports confirmed with password_confirmation', () async {
      final okData = <String, dynamic>{
        'password': 'secret123',
        'password_confirmation': 'secret123',
      };
      final failData = <String, dynamic>{
        'password': 'secret123',
        'password_confirmation': 'wrong',
      };
      const rules = <String, String>{
        'password': 'required|string|min:8|confirmed',
      };

      await Validator.validate(okData, rules);
      expect(
        () => Validator.validate(failData, rules),
        throwsA(isA<ValidationException>()),
      );
    });

    test('supports confirmed with confirm_<field>', () async {
      final data = <String, dynamic>{
        'password': 'secret123',
        'confirm_password': 'secret123',
      };
      const rules = <String, String>{
        'password': 'required|string|min:8|confirmed',
      };

      await Validator.validate(data, rules);
    });

    test('returns custom messages with placeholders and precedence', () async {
      final data = <String, dynamic>{
        'email': '',
      };
      const rules = <String, String>{
        'email': 'required|email|min:5',
      };
      final messages = <String, String>{
        'required': 'global required :field',
        'email': 'field fallback :field',
        'email.required': 'specific required for :field',
      };

      expect(
        () => Validator.validate(data, rules, messages: messages),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors['email']?.first,
            'email first error',
            equals('specific required for email'),
          ),
        ),
      );
    });

    test('validates list item type and not_in rule', () async {
      final data = <String, dynamic>{
        'values': [1, 2, 'x'],
        'status': 'archived',
      };
      const rules = <String, String>{
        'values': 'list:int',
        'status': 'not_in:archived,blocked',
      };

      expect(
        () => Validator.validate(data, rules),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors.keys.toSet(),
            'error keys',
            containsAll(<String>{'values', 'status'}),
          ),
        ),
      );
    });

    test('allows optional email field when value is missing', () async {
      final data = <String, dynamic>{};
      const rules = <String, String>{
        'email': 'email',
      };

      await Validator.validate(data, rules);
    });

    test('rejects non-list value for list:type rule', () async {
      final data = <String, dynamic>{
        'values': 'not-a-list',
      };
      const rules = <String, String>{
        'values': 'list:int',
      };

      expect(
        () => Validator.validate(data, rules),
        throwsA(
          isA<ValidationException>().having(
            (e) => e.errors['values']?.first,
            'values first error',
            contains('must be a list'),
          ),
        ),
      );
    });

    test('ValidationError is compatible with ValidationException', () {
      final error = ValidationError(
        errors: {
          'email': ['The email field is required.'],
        },
      );

      expect(error, isA<ValidationException>());
      expect(error.code, 422);
      expect(error.errors['email']?.first, 'The email field is required.');
      expect(error.message, error.errors);
    });
  });
}
