import 'package:flutter_riverpod/flutter_riverpod.dart';

/// El reloj de los repositorios falsos de agendas (con `USE_FAKES`): las
/// consultas de ejemplo y el plazo de cancelación salen de acá. Se sobrescribe
/// en las pruebas.
final schedulesClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);
