import 'package:flutter/material.dart';

import '../../../core/utils/ui_date.dart';

/// El período al que corresponden los datos mostrados (el de la respuesta
/// del servidor, no el de los campos Desde y Hasta).
class PeriodLabel extends StatelessWidget {
  const PeriodLabel({super.key, required this.from, required this.to});

  final DateTime from;
  final DateTime to;

  @override
  Widget build(BuildContext context) => Text(
    'Datos del ${formatUiDate(from)} al ${formatUiDate(to)}',
    key: const Key('stats-period-label'),
    style: Theme.of(context).textTheme.bodyMedium,
  );
}
