import 'package:flutter/material.dart';

import '../models/shift_number.dart';
import '../models/shift_numbers_rules.dart';
import 'time_picker_field.dart';

/// Editor de los números de un turno (RF-13): una fila por número con su hora
/// de inicio y de fin, y un generador de números seguidos. Muestra los
/// problemas de [validateNumbers] debajo de la lista.
///
/// Es controlado: la lista vive en quien lo usa. Cada cambio se informa con
/// [onChanged], con los números renumerados 1, 2, 3… en el orden de las filas.
class ShiftNumbersEditor extends StatefulWidget {
  const ShiftNumbersEditor({
    super.key,
    required this.numbers,
    required this.onChanged,
    this.showEmptyError = false,
  });

  final List<ShiftNumber> numbers;
  final ValueChanged<List<ShiftNumber>> onChanged;

  /// Si es verdadero y no hay números, avisa que hace falta al menos uno. Se
  /// activa al intentar guardar, no antes.
  final bool showEmptyError;

  @override
  State<ShiftNumbersEditor> createState() => _ShiftNumbersEditorState();
}

class _ShiftNumbersEditorState extends State<ShiftNumbersEditor> {
  static const int _defaultDuration = 20;
  static const int _lastEnd = 23 * 60 + 55;

  int _generatorStart = 9 * 60;
  int _generatorEnd = 10 * 60;
  int _generatorDuration = _defaultDuration;
  int? _leftoverMinutes;

  List<ShiftNumber> get _numbers => widget.numbers;

  void _emit(List<ShiftNumber> numbers) {
    widget.onChanged([
      for (var i = 0; i < numbers.length; i++)
        numbers[i].copyWith(number: i + 1),
    ]);
  }

  void _update(int index, ShiftNumber number) {
    final updated = [..._numbers]..[index] = number;
    _emit(updated);
  }

  void _remove(int index) {
    _emit([..._numbers]..removeAt(index));
  }

  void _add() {
    final start = _numbers.isEmpty
        ? 9 * 60
        : (_numbers.last.endMinutes).clamp(0, _lastEnd - _defaultDuration);
    _emit([
      ..._numbers,
      ShiftNumber(
        number: _numbers.length + 1,
        startMinutes: start,
        endMinutes: start + _defaultDuration,
      ),
    ]);
  }

  void _generate() {
    final generated = generateConsecutive(
      startMinutes: _generatorStart,
      endMinutes: _generatorEnd,
      durationMinutes: _generatorDuration,
      firstNumber: _numbers.length + 1,
    );
    setState(() {
      _leftoverMinutes = generated.leftoverMinutes > 0
          ? generated.leftoverMinutes
          : null;
    });
    _emit([..._numbers, ...generated.numbers]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errors = _numbers.isEmpty && !widget.showEmptyError
        ? <String>[]
        : validateNumbers(_numbers);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Números del turno', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (var i = 0; i < _numbers.length; i++) _row(i, _numbers[i]),
        for (final error in errors)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              error,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _add,
            icon: const Icon(Icons.add),
            label: const Text('Agregar número'),
          ),
        ),
        const SizedBox(height: 16),
        _generator(theme),
      ],
    );
  }

  Widget _row(int index, ShiftNumber number) {
    return Padding(
      key: Key('number-row-$index'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('N.º ${index + 1}'),
          ),
          TimePickerField(
            keyPrefix: 'number-$index-start',
            label: 'Hora de inicio',
            minutes: number.startMinutes,
            onChanged: (value) =>
                _update(index, number.copyWith(startMinutes: value)),
          ),
          TimePickerField(
            keyPrefix: 'number-$index-end',
            label: 'Hora de fin',
            minutes: number.endMinutes,
            onChanged: (value) =>
                _update(index, number.copyWith(endMinutes: value)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('${number.duration} min'),
          ),
          TextButton(
            onPressed: () => _remove(index),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
  }

  Widget _generator(ThemeData theme) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Generar varios seguidos', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.end,
              children: [
                TimePickerField(
                  keyPrefix: 'generator-start',
                  label: 'Desde',
                  minutes: _generatorStart,
                  onChanged: (value) => setState(() => _generatorStart = value),
                ),
                TimePickerField(
                  keyPrefix: 'generator-end',
                  label: 'Hasta',
                  minutes: _generatorEnd,
                  onChanged: (value) => setState(() => _generatorEnd = value),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Duración de cada número',
                      style: theme.textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<int>(
                        key: const Key('generator-duration'),
                        initialValue: _generatorDuration,
                        isDense: true,
                        items: [
                          for (final minutes in kDurationOptions)
                            DropdownMenuItem(
                              value: minutes,
                              child: Text('$minutes min'),
                            ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _generatorDuration = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                FilledButton.tonal(
                  onPressed: _generate,
                  child: const Text('Generar números'),
                ),
              ],
            ),
            if (_leftoverMinutes != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Sobraron $_leftoverMinutes minutos sin número: no alcanzaban '
                  'para uno más.',
                ),
              ),
          ],
        ),
      ),
    );
  }
}
