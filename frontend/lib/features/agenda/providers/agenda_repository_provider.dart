import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../repositories/agenda_repository.dart';
import '../repositories/api_agenda_repository.dart';

/// Punto único de inyección del repositorio de agenda. Es async porque
/// `dioProvider` lo es (tiene que esperar la configuración de cookies según
/// plataforma antes de devolver el `Dio`).
final agendaRepositoryProvider = FutureProvider<AgendaRepository>((ref) async {
  final dio = await ref.watch(dioProvider.future);
  return ApiAgendaRepository(dio);
});
