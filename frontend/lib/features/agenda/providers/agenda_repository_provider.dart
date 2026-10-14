import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/fakes/fake_database.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/agenda_repository.dart';
import '../repositories/api_agenda_repository.dart';
import '../repositories/fake_agenda_repository.dart';

/// Punto único de inyección del repositorio de agenda. Con `USE_FAKES=true`
/// (ver [useFakesProvider]) devuelve la implementación en memoria; si no, la
/// de la API. Es async porque `dioProvider` lo es (tiene que esperar la
/// configuración de cookies según plataforma antes de devolver el `Dio`).
final agendaRepositoryProvider = FutureProvider<AgendaRepository>((ref) async {
  if (ref.watch(useFakesProvider)) {
    return FakeAgendaRepository(ref.watch(fakeDatabaseProvider));
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiAgendaRepository(dio);
});
