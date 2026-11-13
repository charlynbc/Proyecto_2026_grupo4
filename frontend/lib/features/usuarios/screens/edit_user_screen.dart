import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/widgets/centered_content.dart';
import '../providers/account_detail_provider.dart';
import '../repositories/user_correction_repository.dart';
import '../widgets/edit_user_form.dart';
import 'user_routes.dart';

/// Corrección de los datos de la cuenta [id] (RF-38): se abre con los datos
/// actuales y el administrador cambia lo que haga falta.
class EditUserScreen extends ConsumerWidget {
  const EditUserScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(accountDetailProvider(id));
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Volver',
          onPressed: () => context.go(kUsersPath),
        ),
        title: const Text('Corregir usuario'),
      ),
      body: CenteredContent(
        maxWidth: 560,
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) {
            if (error is UserCorrectionException &&
                error.failure == UserCorrectionFailure.notFound) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('No encontramos esa cuenta.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('edit-user-back'),
                    onPressed: () => context.go(kUsersPath),
                    child: const Text('Volver a Usuarios'),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(apiMessageOf(error)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(accountDetailProvider(id)),
                  child: const Text('Reintentar'),
                ),
              ],
            );
          },
          data: (account) => EditUserForm(detail: account),
        ),
      ),
    );
  }
}
