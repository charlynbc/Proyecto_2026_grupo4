import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/link_check.dart';
import '../repositories/password_recovery_repository.dart';
import 'password_recovery_link_repository_provider.dart';

/// Comprueba el enlace de recuperación una sola vez por token mientras la
/// pantalla lo mira. Sin token no consulta nada. Solo un enlace que el
/// servidor declara inválido bloquea la pantalla; cualquier otro resultado
/// deja pasar al formulario.
final passwordRecoveryLinkCheckProvider = FutureProvider.autoDispose
    .family<LinkCheck, String>((ref, token) async {
      if (token.isEmpty) return const LinkCheck.valid();
      try {
        final repository = await ref.read(
          passwordRecoveryLinkRepositoryProvider.future,
        );
        await repository.validateLink(token: token);
        return const LinkCheck.valid();
      } on InvalidRecoveryLinkException catch (e) {
        return LinkCheck.invalid(e.message);
      } catch (_) {
        return const LinkCheck.valid();
      }
    });
