import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/centered_content.dart';
import '../../../core/widgets/sort_direction_button.dart';
import '../../../core/widgets/ui_date_field.dart';
import '../../auth/widgets/logout_button.dart';
import '../../especialidades/models/specialty.dart';
import '../../especialidades/providers/specialties_provider.dart';
import '../models/appointment_filter_entry.dart';
import '../models/appointment_history_page.dart';
import '../models/appointment_history_query.dart';
import '../models/available_number.dart';
import '../providers/appointment_doctors_provider.dart';
import '../providers/appointment_history_provider.dart';
import '../repositories/appointment_history_repository.dart';
import '../widgets/appointment_card.dart';

const String kAvailabilityPath = '/socio/disponibilidad';
const String kAppointmentsPath = '/socio/consultas';

/// Los estados que ofrece el filtro de Estado: valor de la API y etiqueta, en
/// el orden en que se muestran.
const List<(String, String)> _statuses = [
  ('AGENDADA', 'Agendada'),
  ('ATENDIDA', 'Atendida'),
  ('CANCELADA_SOCIO', 'Cancelada por el socio'),
  ('CANCELADA_INSTITUCION', 'Cancelada por la institución'),
  ('NO_SE_PRESENTO', 'No se presentó'),
  ('NO_ASISTIO', 'No asistió'),
  ('NO_ATENDIDA', 'No atendida'),
];

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

  /// Lo que se ve escrito en Desde y Hasta. Lo aplicado es [_from] y [_to].
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  /// El ancho de cada campo de fecha cuando entran los dos en una fila; con
  /// menos lugar, cada uno ocupa todo el ancho. A 220 px con texto del sistema
  /// al doble la fecha se corta; a 288 px entra.
  static const double _dateFieldWidth = 220;
  static const double _dateFieldsRowWidth = 2 * _dateFieldWidth + 8;

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

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

  /// La fecha que dice un campo: vacío es sin filtro; una fecha válida es esa
  /// fecha; un texto a medias o inexistente deja lo que ya estaba aplicado (el
  /// propio campo avisa del error de formato).
  DateTime? _dateOf(TextEditingController controller, DateTime? applied) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return parseUiDate(text) ?? applied;
  }

  /// Se aplica al instante, como antes. Si Desde queda posterior a Hasta no se
  /// aplica el cambio: queda el último filtro aplicado y se avisa. Solo se
  /// vuelve a la página 1 cuando lo aplicado cambia de verdad.
  void _onDatesChanged() {
    final nextFrom = _dateOf(_fromController, _from);
    final nextTo = _dateOf(_toController, _to);
    if (nextFrom != null && nextTo != null && nextFrom.isAfter(nextTo)) {
      setState(
        () => _filterError =
            'La fecha "Desde" no puede ser posterior a la fecha "Hasta".',
      );
      return;
    }
    final changed = nextFrom != _from || nextTo != _to;
    if (!changed && _filterError == null) return;
    setState(() {
      _from = nextFrom;
      _to = nextTo;
      if (changed) _page = 0;
      _filterError = null;
    });
  }

  // Las opciones de cada desplegable salen de las consultas del socio
  // ([AppointmentFilterEntry]) y dependen de lo elegido en los otros dos: solo
  // se ofrece lo que tiene al menos una consulta que coincida con ellos. Las
  // fechas no entran en el cálculo.

  /// Los estados que se ofrecen, en el orden de [_statuses], dadas la
  /// especialidad y el médico elegidos.
  List<(String, String)> _statusOptions(
    List<AppointmentFilterEntry> entries,
    int? specialtyId,
    int? doctorId,
  ) => [
    for (final status in _statuses)
      if (entries.any(
        (e) =>
            e.status == status.$1 &&
            (specialtyId == null || e.specialtyId == specialtyId) &&
            (doctorId == null || e.doctor.id == doctorId),
      ))
        status,
  ];

  /// Las especialidades que se ofrecen, con el nombre de la propia consulta y
  /// por orden alfabético, dados el estado y el médico elegidos.
  List<({int id, String name})> _specialtyOptions(
    List<AppointmentFilterEntry> entries,
    String? status,
    int? doctorId,
  ) {
    final byId = <int, String>{
      for (final e in entries)
        if ((status == null || e.status == status) &&
            (doctorId == null || e.doctor.id == doctorId))
          e.specialtyId: e.specialtyName,
    };
    return [for (final e in byId.entries) (id: e.key, name: e.value)]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  /// Los médicos que se ofrecen, sin repetir y por el nombre con que los
  /// muestra la tarjeta, dados el estado y la especialidad elegidos.
  List<DoctorRef> _doctorOptions(
    List<AppointmentFilterEntry> entries,
    String? status,
    int? specialtyId,
  ) {
    final byId = <int, DoctorRef>{
      for (final e in entries)
        if ((status == null || e.status == status) &&
            (specialtyId == null || e.specialtyId == specialtyId))
          e.doctor.id: e.doctor,
    };
    return byId.values.toList()..sort(
      (a, b) => a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
    );
  }

  /// Llegaron consultas nuevas (se agendó o canceló una): lo elegido que ya
  /// no está entre las opciones de su desplegable vuelve a "Todos", y se
  /// vuelve a la página 1. Desde los desplegables no se puede llegar a esa
  /// situación, porque ofrecen solo valores con consultas.
  void _reconcile(List<AppointmentFilterEntry> entries) {
    final statusOk =
        _status == null ||
        _statusOptions(
          entries,
          _specialtyId,
          _doctorId,
        ).any((s) => s.$1 == _status);
    final specialtyOk =
        _specialtyId == null ||
        _specialtyOptions(
          entries,
          _status,
          _doctorId,
        ).any((s) => s.id == _specialtyId);
    final doctorOk =
        _doctorId == null ||
        _doctorOptions(
          entries,
          _status,
          _specialtyId,
        ).any((d) => d.id == _doctorId);
    if (statusOk && specialtyOk && doctorOk) return;
    setState(() {
      if (!statusOk) _status = null;
      if (!specialtyOk) _specialtyId = null;
      if (!doctorOk) _doctorId = null;
      _page = 0;
    });
  }

  void _clearFilters() {
    _fromController.clear();
    _toController.clear();
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
    ref.listen(appointmentDoctorsProvider, (_, next) {
      final entries = next.value;
      if (mounted && !next.isLoading && entries != null) _reconcile(entries);
    });
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
    AsyncValue<List<AppointmentFilterEntry>> doctors,
  ) {
    // Mientras la lista de consultas carga o si falla, Estado y Especialidad
    // ofrecen todas sus opciones (los estados completos y el catálogo).
    final entries = doctors.value;
    final statusOptions = entries == null
        ? _statuses
        : _statusOptions(entries, _specialtyId, _doctorId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          key: const Key('history-filter-status'),
          isExpanded: true,
          initialValue: statusOptions.any((s) => s.$1 == _status)
              ? _status
              : null,
          decoration: const InputDecoration(labelText: 'Estado'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
            for (final (value, label) in statusOptions)
              DropdownMenuItem<String?>(value: value, child: Text(label)),
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
          data: (items) {
            final options = entries == null
                ? [for (final s in items) (id: s.id, name: s.name)]
                : _specialtyOptions(entries, _status, _doctorId);
            return DropdownButtonFormField<int?>(
              key: const Key('history-filter-specialty'),
              isExpanded: true,
              initialValue: options.any((s) => s.id == _specialtyId)
                  ? _specialtyId
                  : null,
              decoration: const InputDecoration(labelText: 'Especialidad'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('Todas')),
                for (final specialty in options)
                  DropdownMenuItem<int?>(
                    value: specialty.id,
                    child: Text(specialty.name),
                  ),
              ],
              onChanged: (value) => setState(() {
                _specialtyId = value;
                _page = 0;
              }),
            );
          },
        ),
        const SizedBox(height: 8),
        _doctorFilter(doctors, specialties.value),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth < _dateFieldsRowWidth
                ? constraints.maxWidth
                : _dateFieldWidth;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: width,
                  child: UiDateField(
                    key: const Key('history-date-from'),
                    controller: _fromController,
                    label: 'Desde',
                    pickerHelpText: 'Fecha desde',
                    pickerTooltip: 'Elegir la fecha desde',
                    firstDate: DateTime.utc(2000),
                    lastDate: DateTime.utc(2100),
                    onChanged: (_) => _onDatesChanged(),
                  ),
                ),
                SizedBox(
                  width: width,
                  child: UiDateField(
                    key: const Key('history-date-to'),
                    controller: _toController,
                    label: 'Hasta',
                    pickerHelpText: 'Fecha hasta',
                    pickerTooltip: 'Elegir la fecha hasta',
                    firstDate: DateTime.utc(2000),
                    lastDate: DateTime.utc(2100),
                    // El calendario de "Hasta" abre en la fecha de "Desde", si
                    // es válida.
                    initialPickerDate: () => parseUiDate(_fromController.text),
                    onChanged: (_) => _onDatesChanged(),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 190,
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
            SortDirectionButton(
              key: const Key('history-filter-direction'),
              ascending: _direction == AppointmentHistoryDirection.ascending,
              onPressed: () => setState(() {
                _direction = _direction == AppointmentHistoryDirection.ascending
                    ? AppointmentHistoryDirection.descending
                    : AppointmentHistoryDirection.ascending;
                _page = 0;
              }),
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

  /// El desplegable de médico: "Todos" y los médicos de las consultas del
  /// socio que coinciden con el Estado y la Especialidad elegidos. Queda
  /// deshabilitado, con su explicación, mientras carga, si falla o si no hay
  /// médicos para los filtros elegidos; el listado y los demás filtros no
  /// dependen de él.
  Widget _doctorFilter(
    AsyncValue<List<AppointmentFilterEntry>> doctors,
    List<Specialty>? specialties,
  ) {
    final entries = doctors.value;
    final options = entries == null
        ? const <DoctorRef>[]
        : _doctorOptions(entries, _status, _specialtyId);
    final specialtyId = _specialtyId;
    String? specialtyName;
    for (final specialty in specialties ?? const <Specialty>[]) {
      if (specialty.id == specialtyId) specialtyName = specialty.name;
    }
    for (final e in entries ?? const <AppointmentFilterEntry>[]) {
      if (e.specialtyId == specialtyId) specialtyName = e.specialtyName;
    }
    final help = switch ((entries, doctors.hasError, options.isEmpty)) {
      (null, true, _) => 'No se pudieron cargar los médicos',
      (null, false, _) => 'Cargando médicos',
      (final all?, _, true) when all.isEmpty =>
        'No tenés consultas con médicos',
      (_, _, true) => 'No tenés consultas con médicos para estos filtros',
      _ when specialtyId == null => 'Médicos de tus consultas',
      _ =>
        'Solo médicos de ${specialtyName ?? 'esta especialidad'} en tus '
            'consultas',
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
