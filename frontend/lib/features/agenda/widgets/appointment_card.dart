import 'package:flutter/material.dart';

import '../../../core/utils/ui_date.dart';
import '../models/appointment.dart';

/// Una consulta del socio en Mis consultas (RF-11): especialidad y estado,
/// fecha y horario, médico y consultorio. Al tocarla se llama [onTap]; la
/// navegación es de quien la usa.
class AppointmentCard extends StatelessWidget {
  const AppointmentCard({super.key, required this.appointment, this.onTap});

  final Appointment appointment;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = appointment;
    return Card(
      child: ListTile(
        key: Key('appointment-${value.id}'),
        title: Text('${value.specialty.name} · ${value.statusLabel}'),
        subtitle: Text(
          '${formatUiDate(value.date)} · ${value.timeRange}\n'
          '${value.doctor.fullName} · ${value.clinic.name}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
