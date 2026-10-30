import 'package:flutter/foundation.dart' show ValueGetter;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../models/shift.dart';
import '../models/suspension_filter.dart';
import '../models/suspension_preview.dart';
import '../models/suspension_result.dart';
import '../repositories/shift_repository.dart';
import '../repositories/shift_suspension_repository.dart';
import 'shift_suspension_repository_provider.dart';
import 'shifts_page_provider.dart';
import 'suspension_candidates_provider.dart';
import 'suspension_clock_provider.dart';

/// Máximo de caracteres de la observación, ya recortada (contrato #24).
const int kMaxSuspensionObservationLength = 1000;

/// Qué está esperando la pantalla.
enum SuspendPhase { idle, previewing, confirming }

enum _Action { preview, confirm }

/// El estado de la pantalla de suspender fechas (RF-14).
class SuspendShiftsState {
  const SuspendShiftsState({
    this.filter,
    this.selectedIds = const {},
    this.observation = '',
    this.phase = SuspendPhase.idle,
    this.preview,
    this.previewedIds,
    this.error,
    this.result,
  });

  /// El filtro efectivo (con "desde" ajustado a hoy): el que arma la lista y
  /// el que se manda al suspender.
  final SuspensionFilter? filter;
  final Set<int> selectedIds;
  final String observation;
  final SuspendPhase phase;

  /// Lo que se mostraría al confirmar; `null` si no se pidió o se descartó.
  final SuspensionPreview? preview;

  /// Los ids con que se pidió la vista previa, ordenados: la foto de lo que se
  /// mostró. Es lo que se suspende al confirmar, aunque la selección haya
  /// cambiado mientras tanto. Se renueva y se borra junto con [preview].
  final List<int>? previewedIds;

  /// El mensaje del último error, para mostrar tal cual.
  final String? error;

  /// El resultado de la última suspensión, para avisarlo.
  final SuspensionResult? result;

  SuspendShiftsState copyWith({
    Set<int>? selectedIds,
    String? observation,
    SuspendPhase? phase,
    ValueGetter<SuspensionPreview?>? preview,
    ValueGetter<List<int>?>? previewedIds,
    ValueGetter<String?>? error,
  }) => SuspendShiftsState(
    filter: filter,
    selectedIds: selectedIds ?? this.selectedIds,
    observation: observation ?? this.observation,
    phase: phase ?? this.phase,
    preview: preview != null ? preview() : this.preview,
    previewedIds: previewedIds != null ? previewedIds() : this.previewedIds,
    error: error != null ? error() : this.error,
    result: result,
  );
}

/// Selección, previsualización y confirmación de la suspensión de fechas.
class SuspendShiftsController extends Notifier<SuspendShiftsState> {
  ProviderSubscription<AsyncValue<List<Shift>>>? _candidates;
  _Action? _lastAction;

  @override
  SuspendShiftsState build() {
    ref.onDispose(() => _candidates?.close());
    return const SuspendShiftsState();
  }

  /// Cambia el filtro: limpia la selección, la vista previa y el error, y
  /// conserva la observación. Mientras se espera al servidor (vista previa o
  /// confirmación) no hace nada: cambiar lo elegido en ese momento dejaría la
  /// pantalla mostrando otra cosa que lo que se va a suspender.
  void setFilter(SuspensionFilter filter) {
    if (state.phase != SuspendPhase.idle) return;
    final effective = filter.fromTodayOn(ref.read(suspensionClockProvider)());
    _lastAction = null;
    state = SuspendShiftsState(
      filter: effective,
      observation: state.observation,
    );

    _candidates?.close();
    _candidates = ref.listen(suspensionCandidatesProvider(effective), (
      _,
      next,
    ) {
      // Solo con datos nuevos: cargando o con error no se toca nada.
      if (next is AsyncData<List<Shift>>) _retainOnly(next.value);
    }, fireImmediately: true);
  }

  /// Saca de la selección los ids que ya no están entre los [candidates].
  void _retainOnly(List<Shift> candidates) {
    final available = {for (final shift in candidates) shift.id};
    final kept = state.selectedIds.intersection(available);
    if (kept.length != state.selectedIds.length) {
      state = state.copyWith(selectedIds: kept);
    }
  }

  /// Los tres métodos de selección no hacen nada mientras se espera al
  /// servidor, por la misma razón que [setFilter].
  void toggleSelection(int id) {
    if (state.phase != SuspendPhase.idle) return;
    final next = {...state.selectedIds};
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(selectedIds: next);
  }

  void selectAll(Iterable<int> ids) {
    if (state.phase != SuspendPhase.idle) return;
    state = state.copyWith(selectedIds: {...ids});
  }

  void clearSelection() {
    if (state.phase != SuspendPhase.idle) return;
    state = state.copyWith(selectedIds: {});
  }

  void setObservation(String text) =>
      state = state.copyWith(observation: text, error: () => null);

  /// "Volver": descarta la vista previa y el error que venía con ella.
  /// Conserva selección y observación.
  void dismissPreview() => state = state.copyWith(
    preview: () => null,
    previewedIds: () => null,
    error: () => null,
  );

  /// Pide al servidor qué pasaría al suspender lo elegido.
  Future<void> requestPreview() async {
    if (state.phase != SuspendPhase.idle ||
        state.filter == null ||
        state.selectedIds.isEmpty) {
      return;
    }
    // La foto de lo pedido se toma ahora, antes de cualquier espera: es lo que
    // se va a mostrar y, si se confirma, lo que se va a suspender.
    final ids = _sortedSelection();
    _lastAction = _Action.preview;
    state = state.copyWith(phase: SuspendPhase.previewing, error: () => null);
    await _runPreview(ids);
  }

  /// Suspende las fechas de la vista previa, con el total que se vio en ella.
  /// Manda los ids de la vista previa, no la selección de ahora.
  Future<void> confirm() async {
    final preview = state.preview;
    final previewedIds = state.previewedIds;
    final filter = state.filter;
    if (state.phase != SuspendPhase.idle ||
        preview == null ||
        previewedIds == null ||
        filter == null) {
      return;
    }
    final observation = state.observation.trim();
    if (observation.length > kMaxSuspensionObservationLength) {
      state = state.copyWith(
        error: () =>
            'La observación puede tener hasta $kMaxSuspensionObservationLength '
            'caracteres. Acortala y confirmá de nuevo.',
      );
      return;
    }
    _lastAction = _Action.confirm;
    state = state.copyWith(phase: SuspendPhase.confirming, error: () => null);

    try {
      final repository = await ref.read(
        shiftSuspensionRepositoryProvider.future,
      );
      final result = await repository.suspend(
        filter: filter,
        ids: previewedIds,
        observation: observation.isEmpty ? null : observation,
        confirmedCount: preview.totalAppointments,
      );
      if (!ref.mounted) return;
      _lastAction = null;
      state = SuspendShiftsState(filter: filter, result: result);
      ref.invalidate(suspensionCandidatesProvider(filter));
      ref.invalidate(shiftsPageProvider);
    } on StaleSuspensionConfirmationException catch (e) {
      if (!ref.mounted) return;
      // La cantidad cambió: se vuelve a previsualizar para que se confirme el
      // total nuevo, y se conserva el aviso. Se piden los mismos ids de la
      // vista previa anterior, no la selección de ahora.
      _lastAction = _Action.preview;
      state = state.copyWith(
        phase: SuspendPhase.previewing,
        error: () => e.message,
      );
      await _runPreview(previewedIds, afterStale: true);
    } catch (e) {
      if (!ref.mounted) return;
      _fail(e);
    }
  }

  /// Repite la última acción que falló.
  Future<void> retry() => switch (_lastAction) {
    _Action.preview => requestPreview(),
    _Action.confirm => confirm(),
    null => Future.value(),
  };

  /// Pide la vista previa de [ids] y, si llega, la deja junto con esos ids.
  Future<void> _runPreview(List<int> ids, {bool afterStale = false}) async {
    try {
      final repository = await ref.read(
        shiftSuspensionRepositoryProvider.future,
      );
      final preview = await repository.preview(ids);
      if (!ref.mounted) return;
      state = state.copyWith(
        phase: SuspendPhase.idle,
        preview: () => preview,
        previewedIds: () => ids,
      );
    } catch (e) {
      if (!ref.mounted) return;
      _fail(e);
      // Tras una desactualización, la vista previa vieja ya no vale.
      if (afterStale) {
        state = state.copyWith(preview: () => null, previewedIds: () => null);
      }
    }
  }

  List<int> _sortedSelection() => state.selectedIds.toList()..sort();

  /// Deja el error a la vista y ajusta el resto según de qué error se trate.
  void _fail(Object error) {
    final message = apiMessageOf(error);
    switch (error) {
      case ShiftNotFoundException():
        // Alguna fecha ya no existe: la selección no sirve.
        ref.invalidate(suspensionCandidatesProvider(state.filter!));
        state = state.copyWith(
          phase: SuspendPhase.idle,
          selectedIds: {},
          preview: () => null,
          previewedIds: () => null,
          error: () => message,
        );
      case ShiftNotSuspendableException():
        // Alguna fecha cambió: la vista previa no vale, la selección se
        // ajusta sola al recargar la lista.
        ref.invalidate(suspensionCandidatesProvider(state.filter!));
        state = state.copyWith(
          phase: SuspendPhase.idle,
          preview: () => null,
          previewedIds: () => null,
          error: () => message,
        );
      default:
        state = state.copyWith(phase: SuspendPhase.idle, error: () => message);
    }
  }
}

final suspendShiftsControllerProvider =
    NotifierProvider.autoDispose<SuspendShiftsController, SuspendShiftsState>(
      SuspendShiftsController.new,
    );
