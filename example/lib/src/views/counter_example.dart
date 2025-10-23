import 'package:flint_dart/flint_ui.dart';

class CounterExample extends FlintTemplate {
  @override
  FlintWidget buildTemplate() {
    return FlintColumn(
      alignment: Alignment.center,
      gap: 20,
      children: [
        // Counter Text
        FlintText(
          '0',
          id: 'counter',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: FlintColors.primary,
          ),
        ),

        // Increment Button
        FlintButton(
          text: 'Increment',
          onClick: FlintAction.script('''
            const el = document.querySelector('#counter');
            let value = parseInt(el.innerText);
            el.innerText = value + 1;
          '''),
        ),

        // Reset Button
        FlintButton(
          text: 'Reset',
          onClick: FlintAction.script('''
            const el = document.querySelector('#counter');
            el.innerText = 0;
          '''),
        ),
      ],
    );
  }
}
