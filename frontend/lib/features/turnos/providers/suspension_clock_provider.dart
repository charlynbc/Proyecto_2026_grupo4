import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/uruguay_time.dart';

/// "Hoy" en Uruguay, como clave de día en UTC, para la suspensión de fechas.
/// Los tests lo sobreescriben para no depender del reloj.
final suspensionClockProvider = Provider<DateTime Function()>(
  (ref) => UruguayTime.today,
);
