import 'package:flutter/material.dart';

import '../../../core/widgets/pending_feature_screen.dart';

const String kAvailabilityPath = '/socio/disponibilidad';
const String kAppointmentsPath = '/socio/consultas';

/// "Mis consultas" del socio. El listado (RF-11) y la cancelación no están en
/// el backend: la pantalla lo dice y no muestra datos ni acciones activas.
class AppointmentsPendingScreen extends StatelessWidget {
  const AppointmentsPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PendingFeatureScreen(
      title: 'Mis consultas',
      features: [
        PendingFeature(
          title: 'Mis consultas e historial (RF-11)',
          detail:
              'El servidor todavía no ofrece el listado de consultas. Cuando '
              'agendás una consulta se te muestran sus datos en el momento, '
              'pero no se puede volver a consultarla desde acá.',
        ),
        PendingFeature(
          title: 'Cancelación de consultas',
          detail: 'El servidor todavía no ofrece la cancelación.',
          disabledAction: 'Cancelar consulta',
        ),
        PendingFeature(
          title: 'Listado de médicos',
          detail:
              'El servidor todavía no ofrece un listado independiente de '
              'médicos. En Disponibilidad se pueden filtrar solo los médicos '
              'que tienen números libres.',
        ),
      ],
    );
  }
}
