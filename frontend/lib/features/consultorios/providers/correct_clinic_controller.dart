import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/network/api_exception.dart';
import '../repositories/clinic_correction_repository.dart';
import 'clinic_correction_repository_provider.dart';
import 'clinic_search_provider.dart';
import 'clinics_provider.dart';

class CorrectClinicState {
  const CorrectClinicState({
    this.status = SubmitStatus.idle,
    this.failure,
    this.errorMessage,
  });

  final SubmitStatus status;
  final ClinicCorrectionFailure? failure;
  final String? errorMessage;

  bool get isLoading => status == SubmitStatus.loading;
}

class CorrectClinicController extends Notifier<CorrectClinicState> {
  @override
  CorrectClinicState build() => const CorrectClinicState();

  void clearError() {
    if (state.status == SubmitStatus.error) {
      state = const CorrectClinicState();
    }
  }

  Future<void> correct(int id, {String? name, String? location}) async {
    if (state.isLoading) return;
    final link = ref.keepAlive();
    state = const CorrectClinicState(status: SubmitStatus.loading);
    try {
      final repository = await ref.read(
        clinicCorrectionRepositoryProvider.future,
      );
      await repository.correct(id, name: name, location: location);
      ref.invalidate(clinicsProvider);
      ref.invalidate(clinicSearchProvider);
      state = const CorrectClinicState(status: SubmitStatus.done);
    } catch (error) {
      state = CorrectClinicState(
        status: SubmitStatus.error,
        failure: error is ClinicCorrectionException
            ? error.failure
            : ClinicCorrectionFailure.other,
        errorMessage: apiMessageOf(error),
      );
    } finally {
      link.close();
    }
  }
}

final correctClinicControllerProvider =
    NotifierProvider.autoDispose<CorrectClinicController, CorrectClinicState>(
      CorrectClinicController.new,
    );
