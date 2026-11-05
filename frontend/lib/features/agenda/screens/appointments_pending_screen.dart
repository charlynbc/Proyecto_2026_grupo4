import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/utils/uruguay_time.dart';
import '../../../core/widgets/centered_content.dart';
import '../../auth/widgets/logout_button.dart';
import '../../especialidades/models/specialty.dart';
import '../../especialidades/providers/specialties_provider.dart';
import '../models/appointment_doctor.dart';
import '../models/appointment_history_page.dart';
import '../models/appointment_history_query.dart';
import '../models/available_number.dart';
import '../providers/appointment_doctors_provider.dart';
import '../providers/appointment_history_provider.dart';
import '../repositories/appointment_history_repository.dart';
import '../widgets/appointment_card.dart';

const String kAvailabilityPath = '/socio/disponibilidad';
const String kAppointmentsPath = '/socio/consultas';

/// Mis consultas del socio: listado paginado con filtros que se aplican al
/// elegirlos. El filtro de médico ofrece solo a los médicos con los que el
/// socio tuvo consultas (de sus propias consultas, no del catálogo), y si hay
/// una especialidad elegida, solo a los de esa especialidad.
class AppointmentsPendingScreen extends ConsumerStatefulWidget {
  const AppointmentsPendingScreen({super.key});

  @override
  ConsumerState<AppointmentsPendingScreen> createState() =>
      _AppointmentsPendingScreenState();
}

class _AppointmentsPendingScreenState
    extends ConsumerState<AppointmentsPendingScreen> {
  String? _status;
  DateTime? _from;
  DateTime? _to;
  int? _specialtyId;
  int? _doctorId;
  AppointmentHistoryOrder _order = AppointmentHistoryOrder.date;
  AppointmentHistoryDirection _direction =
      AppointmentHistoryDirection.descending;
  int _page = 0;
  String? _filterError;

  AppointmentHistoryQuery get _query => AppointmentHistoryQuery(
    status: _status,
    from: _from,
    to: _to,
    specialtyId: _specialtyId,
    doctorId: _doctorId,
    order: _order,
    direction: _direction,
    page: _page,
  );

  Future<void> _chooseDate({required bool start}) async {
    final current = start ? _from : _to;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? UruguayTime.today(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    final date = DateTime.utc(picked.year, picked.month, picked.day);
    final nextFrom = start ? date : _from;
    final nextTo = start ? _to : date;
    if (nextFrom != null && nextTo != null && nextFrom.isAfter(nextTo)) {
      setState(
        () => _filterError =
            'La fecha "Desde" no puede ser posterior a la fecha "Hasta".',
      );
      return;
    }
    setState(() {
      _from = nextFrom;
      _to = nextTo;
      _page = 0;
      _filterError = null;
    });
  }

  /// Los médicos que se pueden elegir: los de las consultas del socio, sin
  /// repetir, por el nombre con que los muestra la tarjeta. Con una
  /// especialidad elegida, solo los que tuvieron una consulta de esa
  /// especialidad.
  List<DoctorRef> _doctorOptions(List<AppointmentDoctor> pairs) {
    final byId = <int, DoctorRef>{
      for (final pair in pairs)
        if (_specialtyId == null || pair.specialtyId == _specialtyId)
          pair.doctor.id: pair.doctor,
    };
    return byId.values.toList()..sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
  }

  /// Cambió la especialidad. Si el médico elegido ya no corresponde (no tuvo
  /// consultas de esa especialidad), vuelve a "Todos".
  void _onSpecialtyChanged(int? specialtyId) {
    final pairs = ref.read(appointmentDoctorsProvider).value;
    setState(() {
      _specialtyId = specialtyId;
      final doctorId = _doctorId;
      if (doctorId != null &&
          specialtyId != null &&
          !(pairs ?? const <AppointmentDoctor>[]).any(
            (p) => p.doctor.id == doctorId && p.specialtyId == specialtyId,
          )) {
        _doctorId = null;
      }
      _page = 0;
    });
  }

  void _clearFilters() {
    setState(() {
      _status = null;
      _from = null;
      _to = null;
      _specialtyId = null;
      _doctorId = null;
      _order = AppointmentHistoryOrder.date;
      _direction = AppointmentHistoryDirection.descending;
      _page = 0;
      _filterError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _query;
    final history = ref.watch(appointmentHistoryProvider(query));
    final specialties = ref.watch(specialtiesProvider);
    final doctors = ref.watch(appointmentDoctorsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis consultas'),
        actions: const [LogoutButton()],
      ),
      body: CenteredContent(
        maxWidth: 700,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _filters(specialties, doctors),
              if (_filterError case final error?) ...[
                const SizedBox(height: 8),
                Text(
                  error,
                  key: const Key('history-filter-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              history.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => _loadError(error, query),
                data: (result) => _results(result),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filters(
    AsyncValue<List<Specialty>> specialties,
    AsyncValue<List<AppointmentDoctor>> doctors,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          key: const Key('history-filter-status'),
          isExpanded: true,
          initialValue: _status,
          decoration: const InputDecoration(labelText: 'Estado'),
          items: const [
            DropdownMenuItem<String?>(value: null, child: Text('Todos')),
            DropdownMenuItem(value: 'AGENDADA', child: Text('Agendada')),
            DropdownMenuItem(value: 'ATENDIDA', child: Text('Atendida')),
            DropdownMenuItem(
              value: 'CANCELADA_SOCIO',
              child: Text('Cancelada por el socio'),
            ),
            DropdownMenuItem(
              value: 'CANCELADA_INSTITUCION',
              child: Text('Cancelada por la institución'),
            ),
            DropdownMenuItem(
              value: 'NO_SE_PRESENTO',
              child: Text('No se presentó'),
            ),
            DropdownMenuItem(value: 'NO_ASISTIO', child: Text('No asistió')),
            DropdownMenuItem(value: 'NO_ATENDIDA', child: Text('No atendida')),
          ],
          onChanged: (value) => setState(() {
            _status = value;
            _page = 0;
          }),
        ),
        const SizedBox(height: 8),
        specialties.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text(
            'No se pudieron cargar las especialidades: ${apiMessageOf(error)}',
          ),
          data: (items) => DropdownButtonFormField<int?>(
            key: const Key('history-filter-specialty'),
            isExpanded: true,
            initialValue: _specialtyId,
            decoration: const InputDecoration(labelText: 'Especialidad'),
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
              for (final specialty in items)
                DropdownMenuItem<int?>(
                  value: specialty.id,
                  child: Text(specialty.name),
                ),
            ],
            onChanged: _onSpecialtyChanged,
          ),
        ),
        const SizedBox(height: 8),
        _doctorFilter(doctors, specialties.value),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: const Key('history-date-from'),
              onPressed: () => _chooseDate(start: true),
              child: Text(
                _from == null
                    ? 'Desde: cualquiera'
                    : 'Desde: ${formatUiDate(_from!)}',
              ),
            ),
            OutlinedButton(
              key: const Key('history-date-to'),
              onPressed: () => _chooseDate(start: false),
              child: Text(
                _to == null
                    ? 'Hasta: cualquiera'
                    : 'Hasta: ${formatUiDate(_to!)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<AppointmentHistoryOrder>(
                key: const Key('history-filter-order'),
                isExpanded: true,
                initialValue: _order,
                decoration: const InputDecoration(labelText: 'Ordenar por'),
                items: const [
                  DropdownMenuItem(
                    value: AppointmentHistoryOrder.date,
                    child: Text('Fecha'),
                  ),
                  DropdownMenuItem(
                    value: AppointmentHistoryOrder.specialty,
                    child: Text('Especialidad'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  if (value != null) _order = value;
                  _page = 0;
                }),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<AppointmentHistoryDirection>(
                key: const Key('history-filter-direction'),
                isExpanded: true,
                initialValue: _direction,
                decoration: const InputDecoration(labelText: 'Sentido'),
                items: const [
                  DropdownMenuItem(
                    value: AppointmentHistoryDirection.ascending,
                    child: Text('Ascendente'),
                  ),
                  DropdownMenuItem(
                    value: AppointmentHistoryDirection.descending,
                    child: Text('Descendente'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  if (value != null) _direction = value;
                  _page = 0;
                }),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton(
              key: const Key('history-clear-filters'),
              onPressed: _clearFilters,
              child: const Text('Limpiar'),
            ),
          ],
        ),
      ],
    );
  }

  /// El desplegable de médico: "Todos" y los médicos con los que el socio tuvo
  /// consultas. Queda deshabilitado, con su explicación, mientras carga, si
  /// falla o si no hay médicos para la especialidad elegida; el listado y los
  /// demás filtros no dependen de él.
  Widget _doctorFilter(
    AsyncValue<List<AppointmentDoctor>> doctors,
    List<Specialty>? specialties,
  ) {
    final pairs = doctors.value;
    final options = pairs == null ? const <DoctorRef>[] : _doctorOptions(pairs);
    final specialtyId = _specialtyId;
    String? specialtyName;
    for (final specialty in specialties ?? const <Specialty>[]) {
      if (specialty.id == specialtyId) specialtyName = specialty.name;
    }
    final help = switch ((pairs, doctors.hasError, options.isEmpty)) {
      (null, true, _) => 'No se pudieron cargar los médicos',
      (null, false, _) => 'Cargando médicos',
      (_, _, true) when specialtyId == null =>
        'No tuviste consultas con médicos',
      (_, _, true) => 'No tuviste consultas con médicos de esta especialidad',
      _ when specialtyId == null => 'Médicos con los que tuviste consultas',
      _ =>
        'Solo médicos de ${specialtyName ?? 'esta especialidad'} con los que '
            'tuviste consultas',
    };
    return DropdownButtonFormField<int?>(
      key: const Key('history-filter-doctor'),
      isExpanded: true,
      initialValue: options.any((d) => d.id == _doctorId) ? _doctorId : null,
      decoration: InputDecoration(
        labelText: 'Médico',
        helperText: help,
        helperMaxLines: 2,
      ),
      items: [
        const DropdownMenuItem<int?>(value: null, child: Text('Todos')),
        for (final doctor in options)
          DropdownMenuItem<int?>(
            value: doctor.id,
            child: Text(doctor.fullName, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: options.isEmpty
          ? null
          : (id) => setState(() {
              _doctorId = id;
              _page = 0;
            }),
    );
  }

  Widget _loadError(Object error, AppointmentHistoryQuery query) {
    final message = switch (error) {
      AppointmentHistoryException(
        failure: AppointmentHistoryFailure.unauthenticated,
      ) =>
        'Tu sesión venció. Iniciá sesión nuevamente para ver tus consultas.',
      AppointmentHistoryException(
        failure: AppointmentHistoryFailure.forbidden,
      ) =>
        'Tu cuenta no tiene permiso para ver este historial.',
      AppointmentHistoryException(
        failure: AppointmentHistoryFailure.notFound,
      ) =>
        'No se encontró el historial solicitado.',
      _ => apiMessageOf(error),
    };
    return Column(
      children: [
        Text(
          message,
          key: const Key('history-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => ref.invalidate(appointmentHistoryProvider(query)),
          child: const Text('Reintentar'),
        ),
      ],
    );
  }

  Widget _results(AppointmentHistoryPage result) {
    if (result.items.isEmpty) {
      // Una página que ya no existe (por ejemplo, si se achicó la lista) deja
      // la fila de paginación para volver a la anterior.
      if (result.hasPrevious) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'Esta página ya no tiene consultas.',
                  key: Key('history-empty-page'),
                ),
              ),
            ),
            _pagination(result),
          ],
        );
      }
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No hay consultas que coincidan con los filtros.',
            key: Key('history-empty'),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${result.total} consulta${result.total == 1 ? '' : 's'}',
          key: const Key('history-total'),
        ),
        const SizedBox(height: 8),
        for (final appointment in result.items)
          AppointmentCard(
            appointment: appointment,
            onTap: () => context.push('$kAppointmentsPath/${appointment.id}'),
          ),
        _pagination(result),
      ],
    );
  }

  Widget _pagination(AppointmentHistoryPage result) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          key: const Key('history-previous'),
          onPressed: result.hasPrevious
              ? () => setState(() => _page -= 1)
              : null,
          child: const Text('Anterior'),
        ),
        Text('Página ${result.page + 1}'),
        TextButton(
          key: const Key('history-next'),
          onPressed: result.hasNext ? () => setState(() => _page += 1) : null,
          child: const Text('Siguiente'),
        ),
      ],
    );
  }
}
