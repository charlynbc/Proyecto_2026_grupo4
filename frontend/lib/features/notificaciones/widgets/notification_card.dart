import 'package:flutter/material.dart';

import '../../../core/utils/ui_date_time.dart';
import '../models/app_notification.dart';

/// Un aviso del socio: ícono según el tipo, título, contenido y fecha y hora
/// de Uruguay. Al tocarlo se llama [onTap]; la navegación es de quien lo usa.
class NotificationCard extends StatelessWidget {
  const NotificationCard({super.key, required this.notification, this.onTap});

  final AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final value = notification;
    final (icon, label) = notificationIconFor(value.type);
    return Card(
      child: ListTile(
        key: Key('notification-${value.id}'),
        leading: Icon(
          icon,
          key: Key('notification-icon-${value.id}'),
          semanticLabel: label,
        ),
        title: Text(value.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value.content, key: Key('notification-content-${value.id}')),
            const SizedBox(height: 4),
            Text(
              formatUiDateTime(value.createdAt),
              key: Key('notification-date-${value.id}'),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// El ícono de cada tipo de aviso y la descripción que lee un lector de
/// pantalla. Un tipo que el cliente no conoce usa un ícono genérico.
(IconData, String) notificationIconFor(String type) => switch (type) {
  'AGENDA' => (Icons.event_available, 'Consulta agendada'),
  'CANCELACION' => (Icons.event_busy, 'Consulta cancelada'),
  'SUSPENSION' => (Icons.pause_circle_outline, 'Turno suspendido'),
  'HISTORIA_ACTUALIZADA' => (
    Icons.medical_information_outlined,
    'Historia clínica actualizada',
  ),
  'RECORDATORIO' => (Icons.alarm, 'Recordatorio de consulta'),
  _ => (Icons.notifications_none, 'Aviso'),
};
