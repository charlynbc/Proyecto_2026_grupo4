import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/forms/submit_state.dart';
import '../../../core/network/api_exception.dart';
import '../repositories/specialty_correction_repository.dart';
import 'specialties_provider.dart';
import 'specialty_correction_repository_provider.dart';
import 'specialty_search_provider.dart';

/// El estado de la corrección: el de un envío más el motivo del rechazo, para
/// que la pantalla ponga el aviso en el lugar que corresponde.
class CorrectSpecialtyState extends SubmitState {
  const CorrectSpecialtyState({super.status, super.errorMessage, this.failure});

  /// Solo con [SubmitStatus.error] de una corrección rechazada.
  final SpecialtyCorrectionFailure? failure;
}

/// Corrección de una especialidad (RF-38). Al terminar bien invalida el
/// catálogo y el listado de búsqueda, sin tocar los filtros ni el sentido.
class CorrectSpecialtyController extends Notifier<CorrectSpecialtyState> {
  @override
  CorrectSpecialtyState build() => const CorrectSpecialtyState();

  Future<void> submit(int id, {String? name, bool? requiresReferral}) async {
    if (state.isLoading) return;
    // Si se sale de la pantalla mientras se envía, la corrección igual termina.
    final link = ref.keepAlive();
    state = const CorrectSpecialtyState(status: SubmitStatus.loading);
    try {
      final repository = await ref.read(
        specialtyCorrectionRepositoryProvider.future,
      );
      await repository.correct(
        id,
        name: name,
        requiresReferral: requiresReferral,
      );
      ref.invalidate(specialtiesProvider);
      ref.invalidate(specialtySearchProvider);
      state = const CorrectSpecialtyState(status: SubmitStatus.done);
    } on SpecialtyCorrectionException catch (e) {
      if (e.failure == SpecialtyCorrectionFailure.notFound) {
        // La especialidad ya no está: el catálogo se vuelve a pedir.
        ref.invalidate(specialtiesProvider);
        ref.invalidate(specialtySearchProvider);
      }
      state = CorrectSpecialtyState(
        status: SubmitStatus.error,
        errorMessage: e.message,
        failure: e.failure,
      );
    } catch (e) {
      state = CorrectSpecialtyState(
        status: SubmitStatus.error,
        errorMessage: apiMessageOf(e),
      );
    } finally {
      link.close();
    }
  }
}

final correctSpecialtyControllerProvider =
    NotifierProvider.autoDispose<
      CorrectSpecialtyController,
      CorrectSpecialtyState
    >(CorrectSpecialtyController.new);
