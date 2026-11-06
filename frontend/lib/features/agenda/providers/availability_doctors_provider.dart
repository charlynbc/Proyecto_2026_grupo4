import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/doctor_with_specialties.dart';
import 'agenda_repository_provider.dart';

/// Todos los médicos activos con sus especialidades, para los desplegables de
/// la disponibilidad. Se pide una vez al abrir la pantalla; filtrar por
/// especialidad se hace en el cliente con esta misma lista. `autoDispose`:
/// al salir de la pantalla no queda una lista vieja. Sin reintento automático
/// (`retry` en `null`): la pantalla avisa y ofrece "Reintentar".
final availabilityDoctorsProvider =
    FutureProvider.autoDispose<List<DoctorWithSpecialties>>((ref) async {
      final repository = await ref.watch(agendaRepositoryProvider.future);
      return repository.listDoctors();
    }, retry: (_, _) => null);
