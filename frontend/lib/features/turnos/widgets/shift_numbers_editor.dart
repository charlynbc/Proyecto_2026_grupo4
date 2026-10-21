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
///
/// "Agregar número" y "Generar números" dejan la lista ordenada por hora de
/// inicio. Editar una hora no reordena: así la fila que se está tocando no
/// salta de lugar.
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
  String? _omittedMessage;
  String? _addNotice;
  String? _rangeNotice;

  static const String _invalidRangeMessage =
      'La hora "Hasta" tiene que ser posterior a la hora "Desde": '
      'no se agregó ningún número.';

  List<ShiftNumber> get _numbers => widget.numbers;

  void _emit(List<ShiftNumber> numbers) {
    widget.onChanged([
      for (var i = 0; i < numbers.length; i++)
        numbers[i].copyWith(number: i + 1),
    ]);
  }

  /// Los avisos de "Agregar número" y de "Generar números" con el rango
  /// inválido viven hasta la siguiente acción del editor.
  void _clearNotices() {
    if (_addNotice != null || _rangeNotice != null) {
      setState(() {
        _addNotice = null;
        _rangeNotice = null;
      });
    }
  }

  void _update(int index, ShiftNumber number) {
    _clearNotices();
    final updated = [..._numbers]..[index] = number;
    _emit(updated);
  }

  void _remove(int index) {
    _clearNotices();
    _emit([..._numbers]..removeAt(index));
  }

  /// "Ordenar": deja la lista ordenada por hora de inicio y renumerada 1, 2, 3
  /// a través de [_emit].
  void _sort() {
    _clearNotices();
    _emit(sortNumbers(_numbers));
  }

  /// Agrega un número con lo que tenga el generador en este momento: con la
  /// lista vacía arranca en su hora de inicio y, si no, donde termina el que
  /// termina más tarde (sea cual sea su lugar en la lista); dura la duración
  /// elegida. No lo limita la hora final del generador. Si terminaría después
  /// de las 23:55 (el máximo del selector de horas), no agrega nada y avisa.
  /// La lista queda ordenada por hora.
  void _add() {
    final start = latestEnd(_numbers) ?? _generatorStart;
    final end = start + _generatorDuration;
    if (end > _lastEnd) {
      setState(() {
        _addNotice =
            'No entra otro número de $_generatorDuration minutos antes de '
            'las ${ShiftNumber.formatTime(_lastEnd)}.';
        _rangeNotice = null;
      });
      return;
    }
    _clearNotices();
    _emit(
      sortNumbers([
        ..._numbers,
        ShiftNumber(
          number: _numbers.length + 1,
          startMinutes: start,
          endMinutes: end,
        ),
      ]),
    );
  }

  void _generate() {
    if (_generatorEnd <= _generatorStart) {
      setState(() {
        _leftoverMinutes = null;
        _omittedMessage = null;
        _addNotice = null;
        _rangeNotice = _invalidRangeMessage;
      });
      return;
    }
    final generated = generateConsecutive(
      startMinutes: _generatorStart,
      endMinutes: _generatorEnd,
      durationMinutes: _generatorDuration,
      firstNumber: _numbers.length + 1,
    );
    final filtered = omitCoveredNumbers(
      existing: _numbers,
      generated: generated.numbers,
    );
    setState(() {
      _leftoverMinutes = generated.leftoverMinutes > 0
          ? generated.leftoverMinutes
          : null;
      _omittedMessage = _omittedNotice(filtered.omitted, filtered.kept.length);
      _addNotice = null;
    });
    // Si se omitieron todos no se agrega nada: la lista queda como estaba.
    if (filtered.kept.isNotEmpty) {
      _emit(sortNumbers([..._numbers, ...filtered.kept]));
    }
  }

  /// El aviso de los números generados que ya estaban cargados, o `null` si
  /// no se omitió ninguno.
  static String? _omittedNotice(int omitted, int kept) {
    if (omitted == 0) return null;
    if (kept == 0) {
      return 'Esos números ya estaban cargados: no se agregó ninguno.';
    }
    return omitted == 1
        ? 'Se omitió 1 número que ya estaba cargado.'
        : 'Se omitieron $omitted números que ya estaban cargados.';
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
        if (isOutOfOrder(_numbers))
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(
              key: const Key('unsorted-notice'),
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('Los números no están en orden por hora.'),
                TextButton(onPressed: _sort, child: const Text('Ordenar')),
              ],
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
        if (_addNotice != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _addNotice!,
              style: TextStyle(color: theme.colorScheme.error),
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
                  onChanged: (value) => setState(() {
                    _generatorStart = value;
                    _rangeNotice = null;
                  }),
                ),
                TimePickerField(
                  keyPrefix: 'generator-end',
                  label: 'Hasta',
                  minutes: _generatorEnd,
                  onChanged: (value) => setState(() {
                    _generatorEnd = value;
                    _rangeNotice = null;
                  }),
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
                            setState(() {
                              _generatorDuration = value;
                              _rangeNotice = null;
                            });
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
            if (_rangeNotice != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _rangeNotice!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            if (_omittedMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_omittedMessage!),
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
