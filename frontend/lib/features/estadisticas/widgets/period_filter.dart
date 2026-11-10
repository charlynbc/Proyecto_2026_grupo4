import 'package:flutter/material.dart';

import '../../../core/widgets/ui_date_field.dart';

/// El selector de período de la pestaña: Desde, Hasta y "Consultar".
///
/// No guarda estado: los textos viven en los controllers de quien lo usa, que
/// también decide qué fechas se mandan. Cambiar una fecha solo avisa; la
/// consulta sale al tocar "Consultar".
class PeriodFilter extends StatelessWidget {
  const PeriodFilter({
    super.key,
    required this.fromController,
    required this.toController,
    required this.onFromChanged,
    required this.onToChanged,
    required this.onConsult,
    this.errorText,
  });

  final TextEditingController fromController;
  final TextEditingController toController;
  final ValueChanged<DateTime?> onFromChanged;
  final ValueChanged<DateTime?> onToChanged;

  /// Si es `null` el botón queda deshabilitado (hay una consulta en curso).
  final VoidCallback? onConsult;

  /// El aviso de que el período está al revés.
  final String? errorText;

  static final DateTime _firstDate = DateTime.utc(2020);
  static final DateTime _lastDate = DateTime.utc(2100, 12, 31);

  @override
  Widget build(BuildContext context) {
    final from = UiDateField(
      key: const Key('stats-from'),
      controller: fromController,
      label: 'Desde',
      pickerHelpText: 'Elegí la fecha Desde',
      pickerTooltip: 'Elegir la fecha Desde',
      firstDate: _firstDate,
      lastDate: _lastDate,
      onChanged: onFromChanged,
    );
    final to = UiDateField(
      key: const Key('stats-to'),
      controller: toController,
      label: 'Hasta',
      pickerHelpText: 'Elegí la fecha Hasta',
      pickerTooltip: 'Elegir la fecha Hasta',
      firstDate: _firstDate,
      lastDate: _lastDate,
      onChanged: onToChanged,
    );
    final error = errorText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth >= 480
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: from),
                    const SizedBox(width: 16),
                    Expanded(child: to),
                  ],
                )
              : Column(children: [from, const SizedBox(height: 12), to]),
        ),
        const SizedBox(height: 8),
        Text(
          'Por defecto: mes en curso',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error,
            key: const Key('stats-period-error'),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('stats-consult'),
          onPressed: onConsult,
          child: const Text('Consultar'),
        ),
      ],
    );
  }
}
