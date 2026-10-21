import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/network/api_exception.dart';
import 'clinic_repository_provider.dart';
import 'clinics_provider.dart';

/// Alta de un consultorio (RF-33). Al terminar bien invalida el catálogo.
class CreateClinicController extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  Future<void> submit({required String name, required String location}) async {
    // Si se sale de la pantalla mientras se envía, el alta igual termina.
    final link = ref.keepAlive();
    state = const SubmitState(status: SubmitStatus.loading);
    try {
      final repository = await ref.read(clinicRepositoryProvider.future);
      await repository.create(name: name, location: location);
      ref.invalidate(clinicsProvider);
      state = const SubmitState(status: SubmitStatus.done);
    } catch (e) {
      state = SubmitState(
        status: SubmitStatus.error,
        errorMessage: apiMessageOf(e),
      );
    } finally {
      link.close();
    }
  }
}

final createClinicControllerProvider =
    NotifierProvider.autoDispose<CreateClinicController, SubmitState>(
      CreateClinicController.new,
    );
