import 'package:flutter/material.dart';

import '../models/shift_number.dart';
import '../models/shift_numbers_rules.dart';

/// Una hora del día elegida con dos selectores: la hora (00 a 23) y los
/// minutos de 5 en 5. No es texto libre, así que no se puede elegir una hora
/// que no sea múltiplo de 5. El valor son minutos desde las 00:00.
///
/// Los selectores llevan las claves `<keyPrefix>-hour` y `<keyPrefix>-minute`.
class TimePickerField extends StatelessWidget {
  const TimePickerField({
    super.key,
    required this.keyPrefix,
    required this.label,
    required this.minutes,
    required this.onChanged,
  });

  final String keyPrefix;
  final String label;
  final int minutes;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 84,
              child: DropdownButtonFormField<int>(
                key: Key('$keyPrefix-hour'),
                initialValue: hour,
                isDense: true,
                items: [
                  for (var h = 0; h < 24; h++)
                    DropdownMenuItem(value: h, child: Text(_two(h))),
                ],
                onChanged: (value) {
                  if (value != null) onChanged(value * 60 + minute);
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text(':'),
            ),
            SizedBox(
              width: 84,
              child: DropdownButtonFormField<int>(
                key: Key('$keyPrefix-minute'),
                // Un valor fuera de los pasos de 5 no se puede mostrar: queda
                // vacío y `validateNumbers` lo marca.
                initialValue: minute % kTimeStepMinutes == 0 ? minute : null,
                isDense: true,
                items: [
                  for (var m = 0; m < 60; m += kTimeStepMinutes)
                    DropdownMenuItem(value: m, child: Text(_two(m))),
                ],
                onChanged: (value) {
                  if (value != null) onChanged(hour * 60 + value);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  static String _two(int value) => ShiftNumber.formatTime(value).substring(3);
}
