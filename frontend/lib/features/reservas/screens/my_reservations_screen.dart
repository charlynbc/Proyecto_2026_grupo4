import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/uruguay_time.dart';
import '../../../core/widgets/centered_content.dart';
import '../../agenda/providers/time_slots_provider.dart';
import '../../auth/widgets/logout_button.dart';
import '../models/reservation.dart';
import '../models/reservation_sections.dart';
import '../providers/my_reservations_provider.dart';
import '../providers/reservation_repository_provider.dart';
import '../repositories/reservation_repository.dart';

class MyReservationsScreen extends ConsumerStatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  ConsumerState<MyReservationsScreen> createState() =>
      _MyReservationsScreenState();
}

class _MyReservationsScreenState extends ConsumerState<MyReservationsScreen> {
  int? _cancellingReservationId;

  Future<void> _onCancel(Reservation reservation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar reserva'),
        content: Text(
          '¿Confirmás que querés cancelar el turno con '
          '${reservation.professionalName} el '
          '${_capitalize(DateFormat("EEEE d 'de' MMMM", 'es').format(UruguayTime.toUruguay(reservation.start)))} '
          'de ${DateFormat('HH:mm', 'es').format(UruguayTime.toUruguay(reservation.start))} '
          'a ${DateFormat('HH:mm', 'es').format(UruguayTime.toUruguay(reservation.end))}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Cancelar reserva'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _cancellingReservationId = reservation.id);
    try {
      final repository = await ref.read(reservationRepositoryProvider.future);
      await repository.cancel(reservationId: reservation.id);
      if (!mounted) return;
      ref.invalidate(myReservationsProvider);
      ref.invalidate(timeSlotsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Reserva cancelada.')));
    } on ReservationNotFoundException catch (e) {
      if (!mounted) return;
      ref.invalidate(myReservationsProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } on ReservationException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _cancellingReservationId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myReservations = ref.watch(myReservationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis reservas'),
        actions: const [LogoutButton()],
      ),
      body: CenteredContent(
        maxWidth: 600,
        child: myReservations.when(
          data: (list) {
            if (list.isEmpty) return const Text('Todavía no tenés reservas.');
            final sections = splitReservations(list, DateTime.now());
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Próximas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (sections.upcoming.isEmpty)
                  const Text('No tenés reservas próximas.')
                else
                  Column(
                    children: [
                      for (final r in sections.upcoming)
                        _ReservationCard(
                          reservation: r,
                          cancelling: _cancellingReservationId == r.id,
                          onCancel: () => _onCancel(r),
                        ),
                    ],
                  ),
                const SizedBox(height: 24),
                Text(
                  'Historial',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (sections.history.isEmpty)
                  const Text('Todavía no tenés reservas pasadas.')
                else
                  Column(
                    children: [
                      for (final r in sections.history)
                        _ReservationCard(
                          reservation: r,
                          cancelling: false,
                          onCancel: null,
                        ),
                    ],
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No pudimos cargar tus reservas. Intentá de nuevo.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(myReservationsProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _capitalize(String text) {
  if (text.isEmpty) return text;
  return text[0].toUpperCase() + text.substring(1);
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.cancelling,
    this.onCancel,
  });

  final Reservation reservation;
  final bool cancelling;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final date = _capitalize(
      DateFormat(
        "EEEE d 'de' MMMM",
        'es',
      ).format(UruguayTime.toUruguay(reservation.start)),
    );
    final startTime = DateFormat(
      'HH:mm',
      'es',
    ).format(UruguayTime.toUruguay(reservation.start));
    final endTime = DateFormat(
      'HH:mm',
      'es',
    ).format(UruguayTime.toUruguay(reservation.end));
    final cancelledAt = reservation.cancelledAt;
    final cancelledLine =
        reservation.status == ReservationStatus.cancelled && cancelledAt != null
        ? "\nCancelada el ${DateFormat("EEEE d 'de' MMMM", 'es').format(UruguayTime.toUruguay(cancelledAt))} "
              'a las ${DateFormat('HH:mm', 'es').format(UruguayTime.toUruguay(cancelledAt))}'
        : '';

    return Card(
      child: ListTile(
        title: Text(reservation.professionalName),
        subtitle: Text('$date\n$startTime - $endTime$cancelledLine'),
        isThreeLine: true,
        trailing: onCancel == null
            ? null
            : cancelling
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onCancel,
                child: const Text('Cancelar turno'),
              ),
      ),
    );
  }
}
