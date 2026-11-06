import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/link_check.dart';
import '../repositories/first_login_repository.dart';
import 'first_login_link_repository_provider.dart';

/// Comprueba el enlace de primer ingreso una sola vez por token mientras la
/// pantalla lo mira. Sin token no consulta nada. Solo un enlace que el
/// servidor declara inválido bloquea la pantalla; cualquier otro resultado
/// deja pasar al formulario.
final firstLoginLinkCheckProvider = FutureProvider.autoDispose
    .family<LinkCheck, String>((ref, token) async {
      if (token.isEmpty) return const LinkCheck.valid();
      try {
        final repository = await ref.read(
          firstLoginLinkRepositoryProvider.future,
        );
        await repository.validateLink(token: token);
        return const LinkCheck.valid();
      } on InvalidActivationLinkException catch (e) {
        return LinkCheck.invalid(e.message);
      } catch (_) {
        return const LinkCheck.valid();
      }
    });
