import 'package:flint_dart/flint_ui_core.dart';
import 'package:test/test.dart';

void main() {
  group('form controls', () {
    test('TextField wires label, input, help, and error accessibility', () {
      final field = TextField(
        label: 'Email',
        name: 'email',
        value: 'ada@example.com',
        type: 'email',
        required: true,
        error: 'Email is required',
        helpText: 'Use your work email.',
      );

      expect(field.tag, 'div');
      final label = field.children[0] as FlintElement;
      final input = field.children[1] as FlintElement;

      expect(label.tag, 'label');
      expect(label.props['for'], 'flint-field-email');
      expect(input.tag, 'input');
      expect(input.props['id'], 'flint-field-email');
      expect(input.props['name'], 'email');
      expect(input.props['type'], 'email');
      expect(input.props['value'], 'ada@example.com');
      expect(input.props['required'], true);
      expect(input.props['aria-invalid'], 'true');
      expect(
        input.props['aria-describedby'],
        'flint-field-email-help flint-field-email-error',
      );
    });

    test('TextEditingController controls TextField value', () {
      final controller = TextEditingController(text: 'ada@example.com');
      final field = TextField(
        label: 'Email',
        name: 'email',
        controller: controller,
        value: 'ignored@example.com',
      );

      final input = field.children[1] as FlintElement;
      expect(input.props['value'], 'ada@example.com');
      expect(input.props['onInput'], isA<Function>());

      controller.text = 'grace@example.com';
      final updated = TextField(name: 'email', controller: controller);
      final updatedInput = updated.children.single as FlintElement;
      expect(updatedInput.props['value'], 'grace@example.com');
    });

    test('TextField supports themed input variants and control overrides', () {
      final field = TextField(
        name: 'email',
        variant: InputVariant.soft,
        size: ComponentSize.lg,
        error: 'Invalid email',
        inputDartStyle: const DartStyle(radius: 12),
      );

      final input = field.children.first as FlintElement;
      expect(input.props['className'], contains('flint-s-'));
      expect(
        input.props['style'],
        containsPair('background', 'var(--color-inputSoft, #f9fafb)'),
      );
      expect(input.props['style'], containsPair('min-height', '46px'));
      expect(input.props['style'], containsPair('border-radius', '12px'));
      expect(
        input.props['style'],
        containsPair('border', '1px solid var(--color-dangerSolid, #d92d20)'),
      );
      expect(input.props['_flintStyleCss'], contains('[aria-invalid="true"]'));
      expect(input.props['_flintStyleCss'], contains(':focus-visible'));
    });

    test('TextField supports readonly locked values', () {
      final field = TextField(
        label: 'Email',
        name: 'email',
        value: 'ada@example.com',
        readonly: true,
        helpText: 'Contact support to change it.',
      );

      final input = field.children[1] as FlintElement;

      expect(input.props['readonly'], true);
      expect(input.props['disabled'], isNull);
      expect(input.props['value'], 'ada@example.com');
      expect(input.props['aria-describedby'], 'flint-field-email-help');
      expect(
        input.props['style'],
        containsPair('background', 'var(--color-disabledSurface, #f3f4f6)'),
      );
      expect(input.props['style'], containsPair('cursor', 'default'));
    });

    test('useForm tracks data, errors, reset, and processing state', () async {
      final form = useForm({'email': 'ada@example.com', 'password': ''});
      var notifications = 0;
      form.addListener(() => notifications++);

      form.setField('password', 'secret');
      expect(form.string('password'), 'secret');

      final email = form.controller('email');
      email.text = 'grace@example.com';
      expect(form.string('email'), 'grace@example.com');

      form.setError('email', 'Invalid email');
      expect(form.error('email'), 'Invalid email');

      final result = await form.submit<int>((data) async {
        expect(form.processing, true);
        expect(data['email'], 'grace@example.com');
        return 200;
      });

      expect(result, 200);
      expect(form.processing, false);
      expect(form.wasSuccessful, true);
      expect(form.recentlySuccessful, true);

      form.reset(['email']);
      expect(form.string('email'), 'ada@example.com');
      expect(notifications, greaterThan(0));
    });

    test('FormErrors maps backend payloads into field messages', () {
      final errors = FormErrors.from({
        'message': 'Validation failed',
        'errors': {
          'email': ['Email is required', 'Email must be valid'],
          'password': 'Password is required',
        },
      });

      expect(errors.field('email'), 'Email is required');
      expect(errors.fieldMessages('email'), [
        'Email is required',
        'Email must be valid',
      ]);
      expect(errors.field('password'), 'Password is required');
      expect(errors.firstMessages, {
        'email': 'Email is required',
        'password': 'Password is required',
      });
      expect(errors.has('missing'), isFalse);
    });

    test(
      'FormController captures validation errors thrown on submit',
      () async {
        final form = useForm({'email': ''});
        FormErrors? reported;

        final result = await form.submit<int>(
          (_) async => throw {
            'errors': {
              'email': ['Email is required'],
            },
          },
          onValidationError: (errors) => reported = errors,
        );

        expect(result, isNull);
        expect(form.processing, false);
        expect(form.error('email'), 'Email is required');
        expect(reported?.field('email'), 'Email is required');
      },
    );

    test('controls can resolve errors from FormErrors by name', () {
      final errors = FormErrors.from({
        'email': ['Email is required'],
        'bio': 'Bio is too short',
        'plan': 'Choose a plan',
        'terms': 'Accept the terms',
        'role': 'Choose a role',
      });

      final field = TextField(name: 'email', errors: errors);
      final input = field.children.first as FlintElement;
      expect(input.props['aria-invalid'], 'true');
      final fieldError = field.children.last as FlintElement;
      expect(
        (fieldError.children.single as FlintText).value,
        'Email is required',
      );

      final area = TextArea(name: 'bio', errors: errors);
      expect(
        (area.children.last as FlintElement).props['id'],
        'flint-textarea-bio-error',
      );

      final select = Select(name: 'plan', errors: errors);
      expect(
        (select.children.first as FlintElement).props['aria-invalid'],
        'true',
      );

      final checkbox = Checkbox(name: 'terms', errors: errors);
      final checkboxLabel = checkbox.children.first as FlintElement;
      final checkboxInput = checkboxLabel.children.first as FlintElement;
      expect(checkboxInput.props['aria-invalid'], 'true');

      final group = RadioGroup(
        name: 'role',
        errors: errors,
        options: const [RadioOption(label: 'Admin', value: 'admin')],
      );
      expect(group.props['aria-invalid'], 'true');
      expect(
        (group.children.last as FlintElement).props['id'],
        'flint-radio-role-error',
      );
    });

    test('TextArea renders value as a control property', () {
      final area = TextArea(
        label: 'Notes',
        name: 'notes',
        value: 'Provision manually',
        rows: 6,
      );

      final textarea = area.children[1] as FlintElement;
      expect(textarea.tag, 'textarea');
      expect(textarea.props['rows'], 6);
      expect(textarea.props['value'], 'Provision manually');
      expect(textarea.children, isEmpty);
    });

    test('Checkbox and Switch render checked states', () {
      final checkbox = Checkbox(
        label: 'Active',
        name: 'active',
        checked: true,
        indeterminate: true,
      );
      final checkboxLabel = checkbox.children.first as FlintElement;
      final checkboxInput = checkboxLabel.children.first as FlintElement;

      expect(checkboxInput.props['type'], 'checkbox');
      expect(checkboxInput.props['checked'], true);
      expect(checkboxInput.props['aria-checked'], 'mixed');

      final toggle = Switch(label: 'Auto renew', name: 'auto_renew');
      final switchLabel = toggle.children.first as FlintElement;
      final switchInput = switchLabel.children.first as FlintElement;
      final switchTrack = switchLabel.children[1] as FlintElement;

      expect(switchInput.props['role'], 'switch');
      expect(switchInput.props['aria-checked'], 'false');
      expect(switchTrack.tag, 'span');
      expect(switchTrack.props['aria-hidden'], 'true');
      expect(
        switchTrack.props['style'],
        containsPair('border-radius', '999px'),
      );
    });

    test('SwitchRow renders settings copy with a trailing switch', () {
      final row = SwitchRow(
        label: 'Account emails',
        name: 'account_emails',
        description: 'Receive important account notices.',
        checked: true,
      );

      expect(row.tag, 'div');
      expect(
        row.props['style'],
        containsPair('justify-content', 'space-between'),
      );

      final copy = row.children.first as FlintElement;
      final label = copy.children.first as FlintElement;
      final description = copy.children.last as FlintElement;
      final toggle = row.children.last as Switch;
      final switchLabel = toggle.children.first as FlintElement;
      final switchInput = switchLabel.children.first as FlintElement;

      expect((label.children.single as FlintText).value, 'Account emails');
      expect(
        (description.children.single as FlintText).value,
        'Receive important account notices.',
      );
      expect(switchInput.props['name'], 'account_emails');
      expect(switchInput.props['checked'], true);
      expect(switchInput.props['aria-label'], 'Account emails');
    });

    test('RadioGroup renders options with selected value', () {
      final group = RadioGroup(
        label: 'Billing cycle',
        name: 'cycle',
        value: 'yearly',
        options: const [
          RadioOption(label: 'Monthly', value: 'monthly'),
          RadioOption(label: 'Yearly', value: 'yearly'),
        ],
      );

      expect(group.tag, 'fieldset');
      final options = group.children[1] as FlintElement;
      final yearlyLabel = options.children[1] as FlintElement;
      final yearlyInput = yearlyLabel.children.first as FlintElement;

      expect(yearlyInput.props['type'], 'radio');
      expect(yearlyInput.props['name'], 'cycle');
      expect(yearlyInput.props['checked'], true);
    });

    test('Select renders placeholder and selected option', () {
      final select = Select(
        label: 'Plan',
        name: 'plan',
        value: 'pro',
        placeholder: 'Choose plan',
        options: const [
          SelectOption(label: 'Starter', value: 'starter'),
          SelectOption(label: 'Pro', value: 'pro'),
        ],
      );

      final control = select.children[1] as FlintElement;
      expect(control.tag, 'select');
      expect(control.props['value'], 'pro');
      expect(control.children, hasLength(3));
      final pro = control.children[2] as FlintElement;
      expect(pro.props['value'], 'pro');
      expect(pro.props['selected'], true);
    });

    test('Select compares typed option values by their DOM string value', () {
      final select = Select(
        name: 'quantity',
        value: '2',
        options: const [
          SelectOption(label: 'One', value: 1),
          SelectOption(label: 'Two', value: 2),
        ],
      );

      final control = select.children.single as FlintElement;
      final selected = control.children[1] as FlintElement;

      expect(control.props['value'], '2');
      expect(selected.props['value'], 2);
      expect(selected.props['selected'], true);
    });

    test('TextArea and Select support input variants', () {
      final area = TextArea(
        name: 'bio',
        variant: InputVariant.ghost,
        size: ComponentSize.sm,
      );
      final textarea = area.children.single as FlintElement;
      expect(
        textarea.props['style'],
        containsPair('background', 'transparent'),
      );
      expect(textarea.props['style'], containsPair('min-height', '96px'));

      final select = Select(
        name: 'plan',
        variant: InputVariant.soft,
        disabled: true,
      );
      final control = select.children.single as FlintElement;
      expect(control.props['disabled'], true);
      expect(control.props['style'], containsPair('opacity', 0.7));
      expect(control.props['_flintStyleCss'], contains(':disabled'));
    });

    test('FileInput, Form, and FieldGroup render expected structure', () {
      final file = FileInput(
        label: 'Certificate',
        name: 'cert',
        accept: '.pem',
        multiple: true,
      );
      final input = file.children[1] as FlintElement;
      expect(input.props['type'], 'file');
      expect(input.props['accept'], '.pem');
      expect(input.props['multiple'], true);

      final form = Form(
        method: 'post',
        action: '/settings',
        loading: true,
        children: [file],
      );
      expect(form.props['method'], 'post');
      expect(form.props['aria-busy'], 'true');
      expect(form.children.single, isA<FileInput>());

      final group = FieldGroup(
        title: 'Security',
        description: 'Certificate settings',
        child: form,
      );
      expect(group.tag, 'section');
      expect(group.children.first, isA<FlintElement>());
      expect(group.children.last, isA<Form>());
    });

    test('DatePicker renders input type date and presets', () {
      final picker = DatePicker(
        label: 'Select Date',
        name: 'event_date',
        value: '2026-08-11',
        min: '2026-01-01',
        max: '2026-12-31',
        presets: const [
          DatePreset(label: 'Today', date: '2026-08-11'),
        ],
      );

      expect(picker.tag, 'div');
      final label = picker.children[0] as FlintElement;
      final wrapper = picker.children[1] as FlintElement;
      final input = wrapper.children[0] as FlintElement;

      expect(label.tag, 'label');
      expect(input.tag, 'input');
      expect(input.props['type'], 'date');
      expect(input.props['value'], '2026-08-11');
      expect(input.props['min'], '2026-01-01');
      expect(input.props['max'], '2026-12-31');
    });

    test('DateRangePicker renders start and end date controls', () {
      final rangePicker = DateRangePicker(
        label: 'Select Range',
        startName: 'start',
        endName: 'end',
        startDate: '2026-08-01',
        endDate: '2026-08-11',
      );

      expect(rangePicker.tag, 'div');
      final label = rangePicker.children[0] as FlintElement;
      expect(label.tag, 'label');
    });
  });
}
