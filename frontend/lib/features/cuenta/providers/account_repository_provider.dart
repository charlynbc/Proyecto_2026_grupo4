import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/session_provider.dart';
import '../repositories/account_repository.dart';
import '../repositories/api_account_repository.dart';
import '../repositories/fake_account_repository.dart';

/// Punto único de inyección del repositorio de la cuenta. Con
/// `USE_FAKES=true` devuelve el falso con la persona de prueba del rol de la
/// sesión.
///
/// Mira solo el rol (`select`), no toda la sesión: así una renovación del
/// token no crea otra instancia del falso, que guarda la cuenta en memoria.
/// Sin sesión no se llega a "Mi cuenta" (el router manda al login); por las
/// dudas se usa el socio.
final accountRepositoryProvider = FutureProvider<AccountRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) {
    final role =
        ref.watch(sessionProvider.select((session) => session.role)) ??
        UserRole.socio;
    return FakeAccountRepository(
      account: FakeAccountRepository.personFor(role),
    );
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiAccountRepository(dio);
});
