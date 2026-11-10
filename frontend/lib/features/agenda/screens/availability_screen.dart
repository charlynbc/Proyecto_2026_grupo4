import 'package:flutter/material.dart';
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
import '../models/doctor_with_specialties.dart';
import '../models/referral.dart';
import '../providers/agenda_repository_provider.dart';
import '../providers/availability_doctors_provider.dart';
import '../providers/availability_provider.dart';
import '../providers/available_referrals_provider.dart';
import '../repositories/agenda_repository.dart';

const String _invalidRangeMessage =
    'La fecha "Desde" no puede ser posterior a la fecha "Hasta".';

/// Disponibilidad y alta de consultas del socio (RF-08 y RF-09): se busca por
/// especialidad, por médico o por ambos, se filtran los números libres y se
/// agenda uno por su `numeroId`.
///
/// La búsqueda es explícita: la especialidad, el médico y las fechas quedan
/// pendientes hasta tocar "Buscar" (o Enter en una fecha), y recién ahí se
/// copian a la búsqueda aplicada, que es la que se consulta. Orden y sentido
/// se aplican al instante sobre la búsqueda aplicada.
///
/// Los dos desplegables están habilitados desde el inicio y se filtran entre
/// sí en el cliente, con la lista de médicos que se pide una sola vez
/// (`GET /api/medicos`): elegir una especialidad deja los médicos que la
/// atienden, y elegir un médico deja sus especialidades. Un médico sin
/// números libres se puede elegir: la búsqueda da la lista vacía.
class AvailabilityScreen extends ConsumerStatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  ConsumerState<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends ConsumerState<AvailabilityScreen> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  // Pendiente: lo que se eligió y todavía no se buscó. Las fechas pendientes
  // son el texto de los dos campos.
  int? _specialtyId;
  int? _doctorId;

  // Aplicado: la búsqueda que se ve en pantalla (sin orden ni sentido, que se
  // aplican al instante; ver [_query]). `null` hasta la primera búsqueda.
  AvailabilityQuery? _applied;

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

  /// La búsqueda aplicada con el orden y el sentido de ahora, o `null` si
  /// todavía no se buscó.
  AvailabilityQuery? get _query =>
      _applied?.withOrder(order: _order, direction: _direction);

  /// Hay una especialidad o un médico elegidos: el mínimo para buscar.
  bool get _hasFilter => _specialtyId != null || _doctorId != null;

  /// Copia lo pendiente a la búsqueda aplicada. Sin especialidad ni médico no
  /// hace nada.
  void _search() {
    if (!_hasFilter) return;
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
      _applied = AvailabilityQuery(
        specialtyId: _specialtyId,
        doctorId: _doctorId,
        from: from,
        to: to,
        order: _order,
        direction: _direction,
      );
    });
  }

  /// Deja especialidad, médico y fechas en "Todos" y vacíos. Sin ningún filtro
  /// no hay nada que consultar, así que también se quita la lista mostrada.
  void _clearFilters() {
    FocusScope.of(context).unfocus();
    _fromController.clear();
    _toController.clear();
    setState(() {
      _specialtyId = null;
      _doctorId = null;
      _applied = null;
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
        title: const Text('Reservar consulta'),
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
            // Una sola cosa: la ayuda mientras no hay búsqueda aplicada, o el
            // resultado de la búsqueda aplicada (lista o aviso de lista vacía).
            if (_query != null)
              _Results(
                query: _query!,
                bookingNumberId: _bookingNumberId,
                busy: _busy,
                onBook: _book,
              )
            else
              const Text(
                'Elegí una especialidad o un médico y tocá Buscar para ver '
                'los números disponibles.',
              ),
          ],
        ),
      ),
    );
  }

  /// El médico [id] de [doctors], o `null` si no se eligió o no está.
  DoctorWithSpecialties? _doctorById(
    List<DoctorWithSpecialties>? doctors,
    int? id,
  ) {
    if (id == null || doctors == null) return null;
    for (final doctor in doctors) {
      if (doctor.id == id) return doctor;
    }
    return null;
  }

  /// Cambió la especialidad pendiente. Si el médico elegido no la atiende, se
  /// vuelve a "Todos" en vez de dejar una combinación que no da resultados.
  void _onSpecialtyChanged(int? id, List<DoctorWithSpecialties>? doctors) {
    setState(() {
      _specialtyId = id;
      final doctor = _doctorById(doctors, _doctorId);
      if (id != null && doctor != null && !doctor.attends(id)) {
        _doctorId = null;
      }
      _dropSearchWithoutFilter();
    });
  }

  /// Sin especialidad ni médico no queda nada que mostrar: se descarta la
  /// búsqueda aplicada y vuelve la ayuda. Así tampoco reaparece la lista
  /// anterior al elegir otro filtro sin tocar Buscar. Va dentro de `setState`.
  void _dropSearchWithoutFilter() {
    if (!_hasFilter) _applied = null;
  }

  Widget _filters(List<Specialty> specialties, DateTime today) {
    final doctorsAsync = ref.watch(availabilityDoctorsProvider);
    final allDoctors = doctorsAsync.value;
    final specialtyId = _specialtyId;
    final chosenDoctor = _doctorById(allDoctors, _doctorId);
    // Cada desplegable ofrece solo lo que es compatible con el otro.
    final doctors = [
      for (final doctor in allDoctors ?? const <DoctorWithSpecialties>[])
        if (specialtyId == null || doctor.attends(specialtyId)) doctor,
    ];
    final specialtyOptions = [
      for (final specialty in specialties)
        if (chosenDoctor == null || chosenDoctor.attends(specialty.id))
          specialty,
    ];
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.start,
      children: [
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<int?>(
            key: const Key('filter-specialty'),
            initialValue: specialtyOptions.any((s) => s.id == specialtyId)
                ? specialtyId
                : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Especialidad'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              for (final specialty in specialtyOptions)
                DropdownMenuItem(
                  value: specialty.id,
                  child: Text(specialty.name),
                ),
            ],
            onChanged: (id) => _onSpecialtyChanged(id, allDoctors),
          ),
        ),
        SizedBox(
          width: 280,
          child: DropdownButtonFormField<int?>(
            key: const Key('filter-doctor'),
            initialValue: doctors.any((d) => d.id == _doctorId)
                ? _doctorId
                : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Médico',
              helperText: doctorsAsync.hasError
                  ? apiMessageOf(doctorsAsync.error!)
                  : (allDoctors == null ? 'Cargando médicos' : null),
              helperMaxLines: 3,
              helperStyle: doctorsAsync.hasError
                  ? TextStyle(color: colorScheme.error)
                  : null,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              for (final doctor in doctors)
                DropdownMenuItem(
                  value: doctor.id,
                  child: Text('${doctor.lastName}, ${doctor.firstName}'),
                ),
            ],
            onChanged: allDoctors == null
                ? null
                : (id) => setState(() {
                    _doctorId = id;
                    _dropSearchWithoutFilter();
                  }),
          ),
        ),
        if (doctorsAsync.hasError && !doctorsAsync.isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: () => ref.invalidate(availabilityDoctorsProvider),
              child: const Text('Reintentar'),
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
            onSubmitted: (_) => _search(),
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
            onSubmitted: (_) => _search(),
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
            key: const Key('availability-search-button'),
            onPressed: _hasFilter ? _search : null,
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
}

class _Results extends ConsumerWidget {
  const _Results({
    required this.query,
    required this.bookingNumberId,
    required this.busy,
    required this.onBook,
  });

  final AvailabilityQuery query;
  final int? bookingNumberId;
  final bool busy;
  final void Function(AvailableNumber number) onBook;

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

/// Pide confirmar el número elegido. Si la especialidad exige pase, pide al
/// servidor los pases del socio y muestra el que se va a usar: el primero que
/// sea de la especialidad y no venza antes de la consulta (el servidor los
/// ordena por vencimiento). Mientras carga, si falla o si no hay un pase
/// utilizable no deja confirmar: el servidor rechazaría el pedido con
/// `PASE_NO_VALIDO`. Si la lista estaba vieja y lo rechaza igual, el mensaje
/// llega por el SnackBar y al reabrir se vuelve a pedir la lista.
class _ConfirmBookingDialog extends ConsumerWidget {
  const _ConfirmBookingDialog({required this.number});

  final AvailableNumber number;

  Referral? _usableReferral(List<Referral> referrals) {
    for (final referral in referrals) {
      if (referral.specialty.id == number.specialty.id &&
          !referral.expiresOn.isBefore(number.date)) {
        return referral;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referrals = number.specialty.requiresReferral
        ? ref.watch(availableReferralsProvider)
        : null;
    final referral = referrals?.hasValue == true && !referrals!.isLoading
        ? _usableReferral(referrals.requireValue)
        : null;
    final canConfirm =
        referrals == null ||
        (referrals.hasValue && !referrals.isLoading && referral != null);
    return AlertDialog(
      scrollable: true,
      title: const Text('Confirmar consulta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Agendás la consulta de ${number.specialty.name} con '
            '${number.doctor.fullName} el ${formatUiDate(number.date)}, de '
            '${number.timeRange}?',
          ),
          if (referrals != null) ...[
            const SizedBox(height: 16),
            referrals.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ReferralsError(
                message: error is ApiException
                    ? error.message
                    : 'No pudimos cargar tus pases.',
                onRetry: () => ref.invalidate(availableReferralsProvider),
              ),
              data: (_) => Text(
                referral == null
                    ? 'No encontramos un pase a ${number.specialty.name} '
                          'vigente para el ${formatUiDate(number.date)}. El '
                          'médico que te atienda puede emitirte uno.'
                    : 'Esta especialidad requiere pase. Se usará el pase a '
                          '${referral.specialty.name}, vigente hasta '
                          '${formatUiDate(referral.expiresOn)}. Se consume al '
                          'confirmar.',
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirm-booking'),
          onPressed: canConfirm
              ? () => Navigator.pop(
                  context,
                  _Confirmation(referralId: referral?.id),
                )
              : null,
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

/// El error de carga de los pases, con su "Reintentar".
class _ReferralsError extends StatelessWidget {
  const _ReferralsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        TextButton(onPressed: onRetry, child: const Text('Reintentar')),
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
      ('Agendada el', bookedAt),
    ];
    return AlertDialog(
      scrollable: true,
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
