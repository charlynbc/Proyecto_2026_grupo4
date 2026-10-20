import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/doctor.dart';
import 'shift_repository_provider.dart';

/// Los médicos activos que ejercen la especialidad [specialtyId], para elegir
/// el médico del alta de un turno.
///
/// Sin reintento automático (`retry` en `null`): el formulario muestra el aviso
/// con "Reintentar" apenas falla, en vez de esperar los reintentos de Riverpod.
final doctorsBySpecialtyProvider = FutureProvider.autoDispose
    .family<List<Doctor>, int>((ref, specialtyId) async {
      final repository = await ref.watch(shiftRepositoryProvider.future);
      return repository.listDoctors(specialtyId: specialtyId);
    }, retry: (_, _) => null);
