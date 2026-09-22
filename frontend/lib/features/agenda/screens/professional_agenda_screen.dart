import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/uruguay_time.dart';
import '../../../core/widgets/centered_content.dart';
import '../models/professional.dart';
import '../models/time_slot.dart';
import '../../reservas/providers/my_reservations_provider.dart';
import '../providers/agenda_repository_provider.dart';
import '../providers/professionals_provider.dart';
import '../providers/time_slots_provider.dart';
import '../repositories/agenda_repository.dart';

class ProfessionalAgendaScreen extends ConsumerStatefulWidget {
  const ProfessionalAgendaScreen({super.key, required this.professionalId});

  final int professionalId;

  @override
  ConsumerState<ProfessionalAgendaScreen> createState() =>
      _ProfessionalAgendaScreenState();
}

class _ProfessionalAgendaScreenState
    extends ConsumerState<ProfessionalAgendaScreen> {
  late DateTime _selectedDay = UruguayTime.today();
  int? _reservingTimeSlotId;

  Professional? _findProfessional(List<Professional> professionals) {
    for (final professional in professionals) {
      if (professional.id == widget.professionalId) return professional;
    }
    return null;
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  Future<void> _onTapTimeSlot(TimeSlot slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar reserva'),
        content: Text(
          '¿Confirmás la reserva de las '
          '${DateFormat('HH:mm', 'es').format(UruguayTime.toUruguay(slot.start))} '
          'a ${DateFormat('HH:mm', 'es').format(UruguayTime.toUruguay(slot.end))}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final day = _selectedDay;
    final params = (professionalId: widget.professionalId, day: day);
    setState(() => _reservingTimeSlotId = slot.id);
    try {
      final repository = await ref.read(agendaRepositoryProvider.future);
      await repository.reserve(timeSlotId: slot.id);
      if (!mounted) return;
      ref.invalidate(timeSlotsProvider(params));
      ref.invalidate(myReservationsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Reserva confirmada.'),
          action: SnackBarAction(
            label: 'Ver mis reservas',
            onPressed: () {
              if (!mounted) return;
              context.go('/mis-reservas');
            },
          ),
        ),
      );
    } on TimeSlotTakenException catch (e) {
      if (!mounted) return;
      ref.invalidate(timeSlotsProvider(params));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } on TimeSlotStartedException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } on AgendaException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _reservingTimeSlotId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final professionalsAsync = ref.watch(professionalsProvider);
    final title = professionalsAsync.maybeWhen(
      data: (list) => _findProfessional(list)?.name ?? 'Agenda',
      orElse: () => 'Agenda',
    );

    final params = (professionalId: widget.professionalId, day: _selectedDay);
    final timeSlotsAsync = ref.watch(timeSlotsProvider(params));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: CenteredContent(
        maxWidth: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final day in UruguayTime.nextDays(7))
                  ChoiceChip(
                    label: Text(_capitalize(DateFormat('EEE d', 'es').format(day))),
                    selected: day == _selectedDay,
                    onSelected: (_) => setState(() => _selectedDay = day),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _capitalize(
                DateFormat("EEEE d 'de' MMMM", 'es').format(_selectedDay),
              ),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            timeSlotsAsync.when(
              data: (slots) {
                if (slots.isEmpty) {
                  return const Text('No hay horarios disponibles para este día.');
                }
                return Column(
                  children: [
                    for (final slot in slots)
                      Card(
                        child: ListTile(
                          title: Text(
                            '${DateFormat('HH:mm', 'es').format(UruguayTime.toUruguay(slot.start))} - '
                            '${DateFormat('HH:mm', 'es').format(UruguayTime.toUruguay(slot.end))}',
                          ),
                          trailing: _reservingTimeSlotId == slot.id
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : null,
                          onTap: _reservingTimeSlotId == null
                              ? () => _onTapTimeSlot(slot)
                              : null,
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No pudimos cargar los horarios. Intentá de nuevo.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => ref.invalidate(timeSlotsProvider(params)),
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
