import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appointment_filter_entry.dart';
import '../models/appointment_history_query.dart';
import 'appointment_history_provider.dart';

/// Cuántas consultas se piden por página (el máximo de `GET /api/consultas`).
const int kAppointmentDoctorsPageSize = 100;

/// Tope de páginas que se piden, para no recorrer un historial sin fin.
const int kAppointmentDoctorsMaxPages = 10;

/// De cada consulta del socio, su estado, su médico y su especialidad, para
/// calcular las opciones de los filtros de Mis consultas (Estado,
/// Especialidad y Médico se filtran entre sí).
///
/// Sale de las propias consultas del socio, en cualquier estado (también las
/// canceladas): `GET /api/consultas` sin filtros, de a
/// [kAppointmentDoctorsPageSize], hasta juntar el total o llegar a
/// [kAppointmentDoctorsMaxPages] páginas. Cada terna estado, médico y
/// especialidad figura una sola vez, en el orden en que aparece.
///
/// `autoDispose` y sin reintento automático (`retry` en `null`): la pantalla
/// avisa apenas falla. Se vuelve a pedir cuando se agenda o cancela una
/// consulta (`appointmentHistoryRefreshProvider`), porque cambian las
/// opciones; cambiar los filtros de la pantalla no la vuelve a pedir.
final appointmentDoctorsProvider =
    FutureProvider.autoDispose<List<AppointmentFilterEntry>>((ref) async {
      ref.watch(appointmentHistoryRefreshProvider);
      final repository = await ref.watch(
        appointmentHistoryRepositoryProvider.future,
      );
      final entries = <AppointmentFilterEntry>{};
      var loaded = 0;
      for (var page = 0; page < kAppointmentDoctorsMaxPages; page++) {
        final result = await repository.list(
          AppointmentHistoryQuery(
            page: page,
            size: kAppointmentDoctorsPageSize,
          ),
        );
        for (final appointment in result.items) {
          entries.add(
            AppointmentFilterEntry(
              status: appointment.status,
              doctor: appointment.doctor,
              specialtyId: appointment.specialty.id,
              specialtyName: appointment.specialty.name,
            ),
          );
        }
        loaded += result.items.length;
        if (result.items.isEmpty || loaded >= result.total) break;
      }
      return entries.toList();
    }, retry: (_, _) => null);
