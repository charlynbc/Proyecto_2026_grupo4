import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/uruguay_time.dart';

/// Hoy en Uruguay, como clave de día en UTC: la fecha con que arranca la
/// consulta de agendas. Se sobrescribe en las pruebas.
final schedulesTodayProvider = Provider<DateTime>((ref) => UruguayTime.today());
