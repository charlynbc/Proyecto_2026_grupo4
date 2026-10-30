import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_exception.dart';
import '../../auth/models/user_role.dart';
import '../../auth/providers/session_provider.dart';
import '../../especialidades/models/specialty.dart';
import '../../especialidades/providers/specialty_repository_provider.dart';
import '../models/medical_history_query.dart';
import 'medical_history_repository_provider.dart';

/// Opciones de los selectores de historia clínica.
class MedicalHistoryOptions {
  const MedicalHistoryOptions({
    this.doctors = const <int, String>{},
    this.specialties = const <Specialty>[],
  });

  final Map<int, String> doctors;
  final List<Specialty> specialties;
}

class _MedicalHistoryOptions extends AsyncNotifier<MedicalHistoryOptions> {
  @override
  Future<MedicalHistoryOptions> build() async {
    ref.listen(
      sessionProvider.select(
        (session) => (session.status, session.role, session.accessToken),
      ),
      (_, _) {
        // Misma transición que el listado: sin valores de la sesión anterior.
        // Uso acotado a Riverpod 3.4.3; revisar al actualizar el paquete.
        // ignore: invalid_use_of_internal_member
        state = const AsyncLoading<MedicalHistoryOptions>().copyWithPrevious(
          AsyncError<MedicalHistoryOptions>(
            const ApiException(
              'La sesión cambió. Estamos actualizando las opciones.',
            ),
            StackTrace.empty,
          ),
        );
        ref.invalidateSelf();
      },
    );
    final session = ref.read(sessionProvider);
    if (!session.isAuthenticated ||
        session.role != UserRole.socio ||
        !(session.accessToken?.isNotEmpty ?? false)) {
      return const MedicalHistoryOptions();
    }

    final useFakes = ref.watch(useFakesProvider);
    final repository = await ref.watch(medicalHistoryRepositoryProvider.future);
    if (!ref.mounted) return const MedicalHistoryOptions();

    // No observa los filtros: las opciones provienen de la historia completa.
    final entries = await repository.list(const MedicalHistoryQuery());
    if (!ref.mounted) return const MedicalHistoryOptions();

    final doctors = <int, String>{
      for (final entry in entries) entry.doctorId: entry.doctorFullName,
    };
    final sortedDoctors = doctors.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final List<Specialty> specialties;
    if (useFakes) {
      final byId = <int, Specialty>{
        for (final entry in entries) entry.specialty.id: entry.specialty,
      };
      specialties = byId.values.toList();
    } else {
      final catalog = await ref.watch(specialtyRepositoryProvider.future);
      if (!ref.mounted) return const MedicalHistoryOptions();
      specialties = [...await catalog.list()];
      if (!ref.mounted) return const MedicalHistoryOptions();
    }
    specialties.sort((a, b) => a.name.compareTo(b.name));

    return MedicalHistoryOptions(
      doctors: Map<int, String>.unmodifiable({
        for (final doctor in sortedDoctors) doctor.key: doctor.value,
      }),
      specialties: List<Specialty>.unmodifiable(specialties),
    );
  }
}

/// Opciones independientes de los filtros y limitadas a la sesión del socio.
final medicalHistoryOptionsProvider =
    AsyncNotifierProvider<_MedicalHistoryOptions, MedicalHistoryOptions>(
      _MedicalHistoryOptions.new,
      retry: (_, _) => null,
    );
