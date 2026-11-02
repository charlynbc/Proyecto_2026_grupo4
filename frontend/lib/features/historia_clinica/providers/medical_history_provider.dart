import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/session_provider.dart';
import '../models/medical_history_entry.dart';
import 'medical_history_filters_controller.dart';
import 'medical_history_repository_provider.dart';

/// Transición sin datos anteriores para un cambio de sesión.
///
/// Riverpod 3.4.3 fusiona los estados simples con el valor anterior. Un estado
/// compuesto de carga y error evita esa fusión y retira la información clínica.
/// El error expresa que la sesión anterior ya no autoriza estos datos.
AsyncValue<T> _sessionLoading<T>() {
  // Uso acotado a la API instalada de Riverpod; revisar al actualizarla.
  // ignore: invalid_use_of_internal_member
  return AsyncLoading<T>().copyWithPrevious(
    AsyncError<T>(
      const ApiException('La sesión cambió. Estamos actualizando la consulta.'),
      StackTrace.empty,
    ),
  );
}

/// Observa la sesión existente, sin implementar autenticación adicional.
SessionState _observeSession(Ref ref, void Function() clearPreviousData) {
  ref.listen(
    sessionProvider.select(
      (session) => (session.status, session.role, session.accessToken),
    ),
    (_, _) {
      // Retira también los datos que AsyncValue conservaría durante la recarga.
      clearPreviousData();
      // Invalida la ejecución anterior: sus respuestas ya no publican estado.
      ref.invalidateSelf();
    },
  );
  return ref.read(sessionProvider);
}

bool _isAuthenticatedMember(SessionState session) =>
    session.isAuthenticated &&
    session.role == UserRole.socio &&
    (session.accessToken?.isNotEmpty ?? false);

class _MedicalHistory extends AsyncNotifier<List<MedicalHistoryEntry>> {
  @override
  Future<List<MedicalHistoryEntry>> build() async {
    final session = _observeSession(ref, () {
      state = _sessionLoading<List<MedicalHistoryEntry>>();
    });
    if (!_isAuthenticatedMember(session)) {
      return const <MedicalHistoryEntry>[];
    }

    final query = ref.watch(medicalHistoryFiltersProvider);
    final repository = await ref.watch(medicalHistoryRepositoryProvider.future);
    if (!ref.mounted) return const <MedicalHistoryEntry>[];
    return repository.list(query);
  }
}

class _MedicalHistoryDetail extends AsyncNotifier<MedicalHistoryEntry> {
  _MedicalHistoryDetail(this.id);

  final int id;

  @override
  Future<MedicalHistoryEntry> build() async {
    final session = _observeSession(ref, () {
      state = _sessionLoading<MedicalHistoryEntry>();
    });
    if (!_isAuthenticatedMember(session)) {
      throw const ApiException(
        'Para consultar tu historia clínica, ingresá con tu cuenta de socio.',
      );
    }

    final repository = await ref.watch(medicalHistoryRepositoryProvider.future);
    if (!ref.mounted) {
      throw const ApiException('La consulta de la atención fue interrumpida.');
    }
    return repository.get(id);
  }
}

/// Listado según los filtros aplicados, con reintento explícito por invalidación.
final medicalHistoryProvider =
    AsyncNotifierProvider<_MedicalHistory, List<MedicalHistoryEntry>>(
      _MedicalHistory.new,
      retry: (_, _) => null,
    );

/// Consulta independiente del detalle, utilizando el mismo repositorio.
final medicalHistoryDetailProvider =
    AsyncNotifierProvider.family<
      _MedicalHistoryDetail,
      MedicalHistoryEntry,
      int
    >(_MedicalHistoryDetail.new, retry: (_, _) => null);
