import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/utils/uruguay_time.dart';
import '../../../core/widgets/centered_content.dart';
import '../../../core/widgets/ui_date_field.dart';
import '../../auth/widgets/logout_button.dart';
import '../providers/appointment_history_provider.dart';
import 'appointments_pending_screen.dart';
import '../../especialidades/models/specialty.dart';
import '../../especialidades/providers/specialties_provider.dart';
import '../models/agenda_time.dart';
import '../models/appointment.dart';
import '../models/availability_query.dart';
import '../models/available_number.dart';
import '../providers/agenda_repository_provider.dart';
import '../providers/availability_provider.dart';
import '../repositories/agenda_repository.dart';

const String _invalidRangeMessage =
    'La fecha "Desde" no puede ser posterior a la fecha "Hasta".';

/// Disponibilidad y alta de consultas del socio (RF-08 y RF-09): se elige una
/// especialidad, se filtran los números libres y se agenda uno por su
/// `numeroId`.
///
/// El listado de médicos no existe en el backend: el filtro por médico ofrece
/// solo los que aparecen en los números libres de la especialidad elegida.
class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();
  Specialty? _specialty;
  int? _doctorId;
  DateTime? _from;
  DateTime? _to;
  AvailabilityOrder _order = AvailabilityOrder.date;
  SortDirection _direction = SortDirection.asc;
  String? _rangeError;

  /// Hay un alta en curso (o su diálogo abierto): corta las pulsaciones
  /// repetidas, que de otro modo agendarían dos veces.
  bool _busy = false;
  int? _bookingNumberId;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  AvailabilityQuery? get _query {
    final specialty = _specialty;
    if (specialty == null) return null;
    return AvailabilityQuery(
      specialtyId: specialty.id,
      doctorId: _doctorId,
      from: _from,
      to: _to,
      order: _order,
      direction: _direction,
    );
  }

  void _applyRange() {
    FocusScope.of(context).unfocus();
    final fromText = _fromController.text.trim();
    final toText = _toController.text.trim();
    if (uiDateError(fromText) != null || uiDateError(toText) != null) return;
    final from = fromText.isEmpty ? null : parseUiDate(fromText);
    final to = toText.isEmpty ? null : parseUiDate(toText);
    if (from != null && to != null && from.isAfter(to)) {
      setState(() => _rangeError = _invalidRangeMessage);
      return;
    }
    setState(() {
      _rangeError = null;
      _from = from;
      _to = to;
    });
  }

  void _clearFilters() {
    FocusScope.of(context).unfocus();
    _fromController.clear();
    _toController.clear();
    setState(() {
      _doctorId = null;
      _from = null;
      _to = null;
      _rangeError = null;
    });
  }

  Future<void> _book(AvailableNumber number) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final confirmation = await showDialog<_Confirmation>(
        context: context,
        builder: (_) => _ConfirmBookingDialog(number: number),
      );
      if (confirmation == null || !mounted) return;

      setState(() => _bookingNumberId = number.numberId);
      final repository = await ref.read(agendaRepositoryProvider.future);
      final appointment = await repository.book(
        numberId: number.numberId,
        referralId: confirmation.referralId,
      );
      if (!mounted) return;
      ref.invalidate(availabilityProvider);
      ref.read(appointmentHistoryRefreshProvider.notifier).refresh();
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => _BookedDialog(
          appointment: appointment,
          onViewAppointments: () {
            // El diálogo está en el navegador raíz; el de la pantalla es el
            // de su rama del shell, y un pop ahí sacaría la pantalla misma.
            Navigator.of(dialogContext).pop();
            context.go(kAppointmentsPath);
          },
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e is BookingException && e.availabilityIsStale) {
        ref.invalidate(availabilityProvider);
      }
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _bookingNumberId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final specialties = ref.watch(specialtiesProvider);
    final today = UruguayTime.today();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Disponibilidad'),
        actions: const [LogoutButton()],
      ),
      body: CenteredContent(
        maxWidth: 600,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...specialties.when(
              loading: () => const [Center(child: CircularProgressIndicator())],
              error: (error, _) => [
                Text(
                  apiMessageOf(error),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => ref.invalidate(specialtiesProvider),
                    child: const Text('Reintentar'),
                  ),
                ),
              ],
              data: (items) => [_filters(items, today)],
            ),
            const SizedBox(height: 16),
            if (_query != null)
              _Results(
                query: _query!,
                bookingNumberId: _bookingNumberId,
                busy: _busy,
                onBook: _book,
                onDoctorsLoaded: _syncDoctor,
              )
            else
              const Text(
                'Elegí una especialidad para ver los números disponibles.',
              ),
          ],
        ),
      ),
    );
  }

  /// Si el médico elegido ya no figura entre los que tienen números (cambió
  /// el rango de fechas), se vuelve a "Todos" en vez de dejar un filtro que no
  /// se puede ver.
  void _syncDoctor(List<DoctorRef> doctors) {
    if (_doctorId != null && !doctors.any((d) => d.id == _doctorId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _doctorId = null);
      });
    }
  }

  Widget _filters(List<Specialty> specialties, DateTime today) {
    final doctors = _doctorOptions;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<int>(
            key: const Key('filter-specialty'),
            initialValue: _specialty?.id,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Especialidad'),
            items: [
              for (final specialty in specialties)
                DropdownMenuItem(
                  value: specialty.id,
                  child: Text(specialty.name),
                ),
            ],
            onChanged: (id) {
              if (id == null) return;
              setState(() {
                _specialty = specialties.firstWhere((s) => s.id == id);
                _doctorId = null;
              });
            },
          ),
        ),
        if (_specialty != null)
          SizedBox(
            width: 280,
            child: DropdownButtonFormField<int?>(
              key: ValueKey('filter-doctor-${_specialty!.id}-$_doctorId'),
              initialValue: doctors.any((d) => d.id == _doctorId)
                  ? _doctorId
                  : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Médico'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Todos')),
                for (final doctor in doctors)
                  DropdownMenuItem(
                    value: doctor.id,
                    child: Text('${doctor.lastName}, ${doctor.firstName}'),
                  ),
              ],
              onChanged: (id) => setState(() => _doctorId = id),
            ),
          ),
        SizedBox(
          width: 200,
          child: UiDateField(
            controller: _fromController,
            label: 'Desde',
            pickerHelpText: 'Fecha desde',
            pickerTooltip: 'Elegir la fecha desde',
            firstDate: today,
            lastDate: today.add(const Duration(days: kMaxAdvanceDays)),
            textInputAction: TextInputAction.search,
            onChanged: (_) {
              if (_rangeError != null) setState(() => _rangeError = null);
            },
            onSubmitted: (_) => _applyRange(),
          ),
        ),
        SizedBox(
          width: 200,
          child: UiDateField(
            controller: _toController,
            label: 'Hasta',
            pickerHelpText: 'Fecha hasta',
            pickerTooltip: 'Elegir la fecha hasta',
            firstDate: today,
            lastDate: today.add(const Duration(days: kMaxAdvanceDays)),
            initialPickerDate: () => parseUiDate(_fromController.text),
            errorText: _rangeError,
            textInputAction: TextInputAction.search,
            onChanged: (_) {
              if (_rangeError != null) setState(() => _rangeError = null);
            },
            onSubmitted: (_) => _applyRange(),
          ),
        ),
        SizedBox(
          width: 190,
          child: DropdownButtonFormField<AvailabilityOrder>(
            key: const Key('filter-order'),
            initialValue: _order,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ordenar por'),
            items: [
              for (final order in AvailabilityOrder.values)
                DropdownMenuItem(value: order, child: Text(order.label)),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _order = value);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: TextButton.icon(
            key: const Key('filter-direction'),
            onPressed: () => setState(
              () => _direction = _direction == SortDirection.asc
                  ? SortDirection.desc
                  : SortDirection.asc,
            ),
            icon: Icon(
              _direction == SortDirection.asc
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
            ),
            label: Text(_direction.label),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: FilledButton.icon(
            onPressed: _applyRange,
            icon: const Icon(Icons.search),
            label: const Text('Buscar'),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: OutlinedButton.icon(
            onPressed: _clearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Limpiar filtros'),
          ),
        ),
      ],
    );
  }

  /// Los médicos con números libres en la especialidad y el rango elegidos,
  /// sin contar el filtro por médico (así se puede volver a otro médico).
  List<DoctorRef> get _doctorOptions {
    final query = _query;
    if (query == null) return const [];
    final numbers =
        ref.watch(availabilityProvider(query.withDoctor(null))).value ??
        const <AvailableNumber>[];
    final byId = <int, DoctorRef>{
      for (final number in numbers) number.doctor.id: number.doctor,
    };
    return byId.values.toList()..sort((a, b) {
      final byName = a.lastName.compareTo(b.lastName);
      return byName != 0 ? byName : a.firstName.compareTo(b.firstName);
    });
  }
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.query,
    required this.bookingNumberId,
    required this.busy,
    required this.onBook,
    required this.onDoctorsLoaded,
  });

  final AvailabilityQuery query;
  final int? bookingNumberId;
  final bool busy;
  final void Function(AvailableNumber number) onBook;
  final void Function(List<DoctorRef> doctors) onDoctorsLoaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(availabilityProvider(query));
    final colorScheme = Theme.of(context).colorScheme;
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(apiMessageOf(error), style: TextStyle(color: colorScheme.error)),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => ref.invalidate(availabilityProvider(query)),
            child: const Text('Reintentar'),
          ),
        ],
      ),
      data: (numbers) {
        if (numbers.isEmpty) {
          return const Text('No hay números disponibles con estos filtros.');
        }
        return Column(
          children: [
            for (final number in numbers)
              Card(
                child: ListTile(
                  key: Key('number-${number.numberId}'),
                  title: Text(
                    '${formatUiDate(number.date)} · ${number.timeRange}',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${number.doctor.fullName} · ${number.specialty.name}\n'
                        '${number.clinic.name} (${number.clinic.location}) · '
                        'Número ${number.number}',
                      ),
                      if (number.specialty.requiresReferral)
                        const Text(
                          'Requiere pase',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: bookingNumberId == number.numberId
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : FilledButton(
                          key: Key('book-${number.numberId}'),
                          onPressed: busy ? null : () => onBook(number),
                          child: const Text('Agendar'),
                        ),
                  onTap: busy ? null : () => onBook(number),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Confirmation {
  const _Confirmation({this.referralId});

  final int? referralId;
}

/// Pide confirmar el número elegido. Si la especialidad exige pase, pide
/// también su identificador: el servidor no ofrece todavía un listado de
/// pases para elegir uno, y valida que sea propio, vigente y sin usar.
class _ConfirmBookingDialog extends StatefulWidget {
  const _ConfirmBookingDialog({required this.number});

  final AvailableNumber number;

  @override
  State<_ConfirmBookingDialog> createState() => _ConfirmBookingDialogState();
}

class _ConfirmBookingDialogState extends State<_ConfirmBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _referralController = TextEditingController();

  @override
  void dispose() {
    _referralController.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_formKey.currentState!.validate()) return;
    final text = _referralController.text.trim();
    Navigator.pop(
      context,
      _Confirmation(referralId: text.isEmpty ? null : int.parse(text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final number = widget.number;
    final needsReferral = number.specialty.requiresReferral;
    return AlertDialog(
      title: const Text('Confirmar consulta'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Agendás la consulta de ${number.specialty.name} con '
              '${number.doctor.fullName} el ${formatUiDate(number.date)}, de '
              '${number.timeRange}?',
            ),
            if (needsReferral) ...[
              const SizedBox(height: 16),
              const Text('Esta especialidad requiere un pase vigente.'),
              const SizedBox(height: 8),
              TextFormField(
                key: const Key('referral-id'),
                controller: _referralController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Número de pase'),
                validator: (value) {
                  final id = int.tryParse((value ?? '').trim());
                  return id == null || id <= 0
                      ? 'Ingresá el número de tu pase.'
                      : null;
                },
                onFieldSubmitted: (_) => _confirm(),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirm-booking'),
          onPressed: _confirm,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

/// Los datos reales de la consulta que devolvió el servidor.
class _BookedDialog extends StatelessWidget {
  const _BookedDialog({
    required this.appointment,
    required this.onViewAppointments,
  });

  final Appointment appointment;
  final VoidCallback onViewAppointments;

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final bookedAt = DateFormat('dd/MM/yyyy HH:mm')
        .format(UruguayTime.toUruguay(a.bookedAt));
    final rows = <(String, String)>[
      ('Estado', a.statusLabel),
      ('Especialidad', a.specialty.name),
      ('Médico', a.doctor.fullName),
      ('Fecha', formatUiDate(a.date)),
      ('Horario', a.timeRange),
      ('Consultorio', '${a.clinic.name} (${a.clinic.location})'),
      ('Número', '${a.number}'),
      if (a.referralId != null) ('Pase', '${a.referralId}'),
      ('Agendada el', bookedAt),
    ];
    return AlertDialog(
      title: const Text('Consulta agendada'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label: ',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextSpan(text: value),
                  ],
                ),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('booked-view-appointments'),
          onPressed: onViewAppointments,
          child: const Text('Mis consultas'),
        ),
        FilledButton(
          key: const Key('booked-ok'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}
