import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../repositories/api_email_change_repository.dart';
import '../repositories/email_change_repository.dart';
import '../repositories/fake_email_change_repository.dart';

/// Punto único de inyección del repositorio de cambio de correo. Con
/// `USE_FAKES=true` devuelve la implementación en memoria.
final emailChangeRepositoryProvider = FutureProvider<EmailChangeRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) return FakeEmailChangeRepository();
  final dio = await ref.watch(dioProvider.future);
  return ApiEmailChangeRepository(dio);
});
