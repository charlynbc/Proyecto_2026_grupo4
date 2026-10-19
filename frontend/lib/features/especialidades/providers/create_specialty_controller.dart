import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/network/api_exception.dart';
import 'specialties_provider.dart';
import 'specialty_repository_provider.dart';

/// Alta de una especialidad (RF-29). Al terminar bien invalida el catálogo.
class CreateSpecialtyController extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  Future<void> submit({
    required String name,
    required bool requiresReferral,
  }) async {
    state = const SubmitState(status: SubmitStatus.loading);
    try {
      final repository = await ref.read(specialtyRepositoryProvider.future);
      await repository.create(name: name, requiresReferral: requiresReferral);
      ref.invalidate(specialtiesProvider);
      state = const SubmitState(status: SubmitStatus.done);
    } catch (e) {
      state = SubmitState(
        status: SubmitStatus.error,
        errorMessage: apiMessageOf(e),
      );
    }
  }
}

final createSpecialtyControllerProvider =
    NotifierProvider.autoDispose<CreateSpecialtyController, SubmitState>(
      CreateSpecialtyController.new,
    );
