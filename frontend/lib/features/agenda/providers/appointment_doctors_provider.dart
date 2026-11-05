import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appointment_doctor.dart';
import '../models/appointment_history_query.dart';
import 'appointment_history_provider.dart';

/// Cuántas consultas se piden por página (el máximo de `GET /api/consultas`).
const int kAppointmentDoctorsPageSize = 100;

/// Tope de páginas que se piden, para no recorrer un historial sin fin.
const int kAppointmentDoctorsMaxPages = 10;

/// Los médicos con los que el socio tuvo consultas, con la especialidad de
/// cada una, para el filtro de médico de Mis consultas.
///
/// Sale de las propias consultas del socio, en cualquier estado (también las
/// canceladas): `GET /api/consultas` sin filtros, de a
/// [kAppointmentDoctorsPageSize], hasta juntar el total o llegar a
/// [kAppointmentDoctorsMaxPages] páginas. Cada par médico y especialidad
/// figura una sola vez, en el orden en que aparece.
///
/// `autoDispose` y sin reintento automático (`retry` en `null`): la pantalla
/// avisa apenas falla. Se vuelve a pedir cuando se agenda o cancela una
/// consulta (`appointmentHistoryRefreshProvider`), porque puede aparecer un
/// médico nuevo; cambiar los filtros de la pantalla no la vuelve a pedir.
final appointmentDoctorsProvider =
    FutureProvider.autoDispose<List<AppointmentDoctor>>((ref) async {
      ref.watch(appointmentHistoryRefreshProvider);
      final repository = await ref.watch(
        appointmentHistoryRepositoryProvider.future,
      );
      final pairs = <AppointmentDoctor>{};
      var loaded = 0;
      for (var page = 0; page < kAppointmentDoctorsMaxPages; page++) {
        final result = await repository.list(
          AppointmentHistoryQuery(
            page: page,
            size: kAppointmentDoctorsPageSize,
          ),
        );
        for (final appointment in result.items) {
          pairs.add(
            AppointmentDoctor(
              doctor: appointment.doctor,
              specialtyId: appointment.specialty.id,
            ),
          );
        }
        loaded += result.items.length;
        if (result.items.isEmpty || loaded >= result.total) break;
      }
      return pairs.toList();
    }, retry: (_, _) => null);
