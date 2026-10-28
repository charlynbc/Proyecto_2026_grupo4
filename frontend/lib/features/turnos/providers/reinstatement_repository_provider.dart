import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/shift_reinstatement_repository.dart';

/// Punto de inyección del repositorio de rehabilitación. Todavía no elige
/// la implementación falsa ni la real: la pantalla no lo usa.
final reinstatementRepositoryProvider =
    FutureProvider<ShiftReinstatementRepository>((ref) async {
      throw UnimplementedError();
    });
