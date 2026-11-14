import 'package:intl/intl.dart';

import 'ui_date.dart';
import 'uruguay_time.dart';

final DateFormat _uiTime = DateFormat('HH:mm');

/// Un instante como `dd/mm/aaaa HH:mm` (RNF-20 y RNF-21): hora de Uruguay y
/// de 24 horas, sin importar la zona del dispositivo ni el offset con que
/// llegó el instante.
String formatUiDateTime(DateTime instant) {
  final uruguay = UruguayTime.toUruguay(instant);
  return '${formatUiDate(uruguay)} ${_uiTime.format(uruguay)}';
}
