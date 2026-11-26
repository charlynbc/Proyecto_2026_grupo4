import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/utils/uruguay_time.dart';
import '../../../core/widgets/centered_content.dart';
import '../../auth/widgets/logout_button.dart';
import '../models/appointment.dart';
import '../providers/appointment_history_provider.dart';
import '../repositories/appointment_history_repository.dart';
import '../widgets/cancel_appointment_dialog.dart';

/// Lo que se le dice al socio cuando el servidor informa `cancelable: false`.
/// Es genérico a propósito: el motivo (llegada ya registrada o falta de plazo)
/// lo decide el servidor y el cliente no lo distingue ni lo recalcula.
const String _cancelUnavailableText =
    'Esta consulta ya no se puede cancelar desde la aplicación. '
    'Si no vas a poder asistir, comunicate con la institución.';

class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointment = ref.watch(appointmentDetailProvider(id));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consulta'),
        actions: const [LogoutButton()],
      ),
      body: CenteredContent(
        maxWidth: 600,
        child: Padding(
          padding: const EdgeInsets.all(16),
          // Al volver a la pantalla se vuelve a pedir el detalle: mientras
          // llega, se sigue viendo el anterior en vez de una ruedita.
          child: appointment.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => _error(context, ref, error),
            data: (value) => _details(context, ref, value),
          ),
        ),
      ),
    );
  }

  Widget _error(BuildContext context, WidgetRef ref, Object error) {
    final message = switch (error) {
      AppointmentHistoryException(
        failure: AppointmentHistoryFailure.unauthenticated,
      ) =>
        'Tu sesión venció. Iniciá sesión nuevamente.',
      AppointmentHistoryException(
        failure: AppointmentHistoryFailure.forbidden,
      ) =>
        'Tu cuenta no tiene permiso para ver esta consulta.',
      AppointmentHistoryException(
        failure: AppointmentHistoryFailure.notFound,
      ) =>
        'No se encontró esta consulta.',
      _ => apiMessageOf(error),
    };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, key: const Key('appointment-detail-error')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ref.invalidate(appointmentDetailProvider(id)),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _details(
    BuildContext context,
    WidgetRef ref,
    Appointment appointment,
  ) {
    final bookedAt = DateFormat('dd/MM/yyyy HH:mm')
        .format(UruguayTime.toUruguay(appointment.bookedAt));
    final rows = <(String, String)>[
      ('Estado', appointment.statusLabel),
      ('Fecha', formatUiDate(appointment.date)),
      ('Número', '${appointment.number}'),
      ('Horario', appointment.timeRange),
      ('Médico', appointment.doctor.fullName),
      ('Especialidad', appointment.specialty.name),
      (
        'Consultorio',
        '${appointment.clinic.name} (${appointment.clinic.location})',
      ),
      ('Agendada el', bookedAt),
      if (appointment.cancelledAt != null)
        (
          'Cancelada el',
          DateFormat('dd/MM/yyyy HH:mm')
              .format(UruguayTime.toUruguay(appointment.cancelledAt!)),
        ),
      if (appointment.cancellationReason != null)
        ('Motivo de cancelación', appointment.cancellationReason!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (label, value) in rows)
          ListTile(title: Text(label), subtitle: Text(value)),
        const SizedBox(height: 8),
        // `cancelable` lo decide el servidor: acá no se recalcula ninguna regla.
        // Con `null` (servidor anterior) se ofrece cancelar como siempre y el
        // 409 de la cancelación protege.
        if (appointment.status == 'AGENDADA' &&
            appointment.cancelable != false) ...[
          OutlinedButton(
            key: const Key('cancel-appointment'),
            onPressed: () => showCancelAppointmentDialog(
              context: context,
              ref: ref,
              appointment: appointment,
            ),
            child: const Text('Cancelar consulta'),
          ),
        ] else if (appointment.status == 'AGENDADA') ...[
          Text(
            _cancelUnavailableText,
            key: const Key('cancel-unavailable'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}
