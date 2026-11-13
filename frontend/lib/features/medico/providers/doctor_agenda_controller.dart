import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/utils/uruguay_time.dart';
import '../../agenda/models/agenda_time.dart';
import '../models/doctor_shift.dart';
import '../repositories/api_doctor_shift_repository.dart';
import '../repositories/doctor_shift_repository.dart';
import '../repositories/fake_doctor_shift_repository.dart';

/// El turno falso. La cancelación lo observa para compartir la misma memoria.
final fakeDoctorShiftRepositoryProvider = Provider<FakeDoctorShiftRepository>(
  (ref) => FakeDoctorShiftRepository(),
);

/// Punto único de inyección del repositorio de turnos del médico.
final doctorShiftRepositoryProvider = FutureProvider<DoctorShiftRepository>((
  ref,
) async {
  if (ref.watch(useFakesProvider)) {
    return ref.watch(fakeDoctorShiftRepositoryProvider);
  }
  final dio = await ref.watch(dioProvider.future);
  return ApiDoctorShiftRepository(dio);
});

/// El instante actual. Los tests lo sobreescriben para no depender del reloj.
final doctorClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// Cada cuánto se vuelve a consultar el servidor (RF-21: la lista se
/// actualiza sola). Se sobrescribe en las pruebas.
final doctorPollIntervalProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

@immutable
class DoctorAgendaState {
  const DoctorAgendaState({
    required this.date,
    this.shifts,
    this.selectedShiftId,
    this.arrivedFilter,
    this.order = DoctorNumbersOrder.time,
    this.ascending = true,
    this.numbers,
    this.loading = true,
    this.error,
    this.refreshError,
    this.updatedAt,
  });

  /// Fecha consultada (`yyyy-MM-dd`).
  final String date;
  final List<DoctorShift>? shifts;
  final int? selectedShiftId;

  /// `null` = todos, `true` = con aviso de llegada, `false` = sin aviso.
  final bool? arrivedFilter;
  final DoctorNumbersOrder order;
  final bool ascending;
  final DoctorShiftNumbers? numbers;
  final bool loading;

  /// Error de una carga explícita (fecha, turno, filtro): no hay datos que mostrar.
  final String? error;

  /// Error de una actualización automática: se conservan los datos y se avisa.
  final String? refreshError;

  /// Última vez que el servidor respondió bien.
  final DateTime? updatedAt;

  DoctorAgendaState copyWith({
    String? date,
    List<DoctorShift>? shifts,
    int? selectedShiftId,
    bool clearShift = false,
    bool? arrivedFilter,
    bool clearArrivedFilter = false,
    DoctorNumbersOrder? order,
    bool? ascending,
    DoctorShiftNumbers? numbers,
    bool clearNumbers = false,
    bool? loading,
    String? error,
    bool clearError = false,
    String? refreshError,
    bool clearRefreshError = false,
    DateTime? updatedAt,
  }) {
    return DoctorAgendaState(
      date: date ?? this.date,
      shifts: shifts ?? this.shifts,
      selectedShiftId: clearShift
          ? null
          : (selectedShiftId ?? this.selectedShiftId),
      arrivedFilter: clearArrivedFilter
          ? null
          : (arrivedFilter ?? this.arrivedFilter),
      order: order ?? this.order,
      ascending: ascending ?? this.ascending,
      numbers: clearNumbers ? null : (numbers ?? this.numbers),
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
      refreshError: clearRefreshError
          ? null
          : (refreshError ?? this.refreshError),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Agenda del médico: fecha, turno elegido, filtro y orden, más el sondeo
/// periódico. Un sondeo no solapa consultas, se pausa con la pantalla oculta,
/// conserva filtro y orden, y solo cambia el estado si los datos cambiaron
/// (sin parpadeos). Al soltarse el provider (salir de la pantalla o cerrar
/// sesión) el temporizador se cancela.
class DoctorAgendaController extends Notifier<DoctorAgendaState> {
  Timer? _timer;
  bool _visible = true;
  bool _inFlight = false;
  int _generation = 0;

  @override
  DoctorAgendaState build() {
    ref.onDispose(() {
      _timer?.cancel();
      _generation++;
    });
    final interval = ref.read(doctorPollIntervalProvider);
    _timer = Timer.periodic(interval, (_) => _poll());
    // El día de hoy es el de Uruguay, no el del aparato (contrato, 1.2).
    final today = formatApiDate(
      UruguayTime.today(now: ref.read(doctorClockProvider)()),
    );
    Future.microtask(() => _load(explicit: true));
    return DoctorAgendaState(date: today);
  }

  /// La pantalla avisa si está a la vista; oculta no se consulta.
  void setVisible(bool visible) {
    final wasHidden = !_visible;
    _visible = visible;
    if (visible && wasHidden) _poll();
  }

  Future<void> setDate(String date) {
    state = state.copyWith(
      date: date,
      clearShift: true,
      clearNumbers: true,
      clearError: true,
      clearRefreshError: true,
      loading: true,
    );
    return _load(explicit: true);
  }

  Future<void> selectShift(int shiftId) {
    state = state.copyWith(
      selectedShiftId: shiftId,
      clearNumbers: true,
      clearError: true,
      clearRefreshError: true,
      loading: true,
    );
    return _load(explicit: true);
  }

  void clearShift() {
    state = state.copyWith(
      clearShift: true,
      clearNumbers: true,
      clearError: true,
      clearRefreshError: true,
    );
  }

  Future<void> setArrivedFilter(bool? arrived) {
    state = state.copyWith(
      arrivedFilter: arrived,
      clearArrivedFilter: arrived == null,
      clearNumbers: true,
      clearError: true,
      clearRefreshError: true,
      loading: true,
    );
    return _load(explicit: true);
  }

  Future<void> setOrder(DoctorNumbersOrder order, {required bool ascending}) {
    state = state.copyWith(
      order: order,
      ascending: ascending,
      clearNumbers: true,
      clearError: true,
      clearRefreshError: true,
      loading: true,
    );
    return _load(explicit: true);
  }

  /// "Actualizar" a mano.
  Future<void> refresh() => _load(explicit: true);

  Future<void> _poll() {
    if (!_visible || state.loading) return Future.value();
    return _load(explicit: false);
  }

  Future<void> _load({required bool explicit}) async {
    if (_inFlight && !explicit) return;
    final generation = ++_generation;
    _inFlight = true;
    final snapshot = state;
    try {
      final repository = await ref.read(doctorShiftRepositoryProvider.future);
      final shifts = await repository.listShifts(snapshot.date);
      DoctorShiftNumbers? numbers;
      final shiftId = snapshot.selectedShiftId;
      if (shiftId != null) {
        numbers = await repository.listNumbers(
          shiftId,
          arrived: snapshot.arrivedFilter,
          order: snapshot.order,
          ascending: snapshot.ascending,
        );
      }
      // Una acción del médico mientras volaba la consulta la deja obsoleta.
      if (generation != _generation) return;
      final unchanged =
          listEquals(shifts, state.shifts) &&
          numbers == state.numbers &&
          !state.loading &&
          state.error == null &&
          state.refreshError == null;
      if (unchanged) return;
      state = state.copyWith(
        shifts: shifts,
        numbers: numbers,
        clearNumbers: numbers == null,
        loading: false,
        clearError: true,
        clearRefreshError: true,
        updatedAt: DateTime.now(),
      );
    } on ApiException catch (e) {
      _fail(generation, explicit, e.message);
    } on Object {
      _fail(generation, explicit, const ApiException().message);
    } finally {
      if (generation == _generation) _inFlight = false;
    }
  }

  void _fail(int generation, bool explicit, String message) {
    if (generation != _generation) return;
    state = explicit
        ? state.copyWith(loading: false, error: message)
        : state.copyWith(refreshError: message);
  }
}

final doctorAgendaControllerProvider =
    NotifierProvider.autoDispose<DoctorAgendaController, DoctorAgendaState>(
      DoctorAgendaController.new,
    );
