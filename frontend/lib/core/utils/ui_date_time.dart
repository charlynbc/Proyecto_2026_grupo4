import 'ui_date.dart';
import 'ui_time.dart';
import 'uruguay_time.dart';

/// Un instante como `dd/mm/aaaa HH:mm` en hora de Uruguay (RNF-16 y RNF-21),
/// sin importar la zona del dispositivo.
String formatUiDateTime(DateTime instant) {
  final local = UruguayTime.toUruguay(instant);
  final day = DateTime.utc(local.year, local.month, local.day);
  return '${formatUiDate(day)} ${formatUiTime(local.hour, local.minute)}';
}
