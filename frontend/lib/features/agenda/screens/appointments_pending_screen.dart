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
import '../models/appointment.dart';
import '../models/appointment_history_page.dart';
import '../models/appointment_history_query.dart';
import '../providers/appointment_history_provider.dart';
import '../repositories/appointment_history_repository.dart';

const String kAvailabilityPath = '/socio/disponibilidad';
const String kAppointmentsPath = '/socio/consultas';

class AppointmentsPendingScreen extends ConsumerStatefulWidget {
  const AppointmentsPendingScreen({super.key});

  @override
  ConsumerState<AppointmentsPendingScreen> createState() =>
      _AppointmentsPendingScreenState();
}

class _AppointmentsPendingScreenState
    extends ConsumerState<AppointmentsPendingScreen> {
  final _doctorController = TextEditingController();
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

  @override
  void dispose() {
    _doctorController.dispose();
    super.dispose();
  }

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

  void _applyFilters() {
    final doctorText = _doctorController.text.trim();
    final doctorId = doctorText.isEmpty ? null : int.tryParse(doctorText);
    if (doctorText.isNotEmpty && (doctorId == null || doctorId <= 0)) {
      setState(() => _filterError = 'El ID del médico debe ser positivo.');
      return;
    }
    setState(() {
      _doctorId = doctorId;
      _page = 0;
      _filterError = null;
    });
  }

  void _clearFilters() {
    _doctorController.clear();
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
              _filters(specialties),
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

  Widget _filters(AsyncValue<List<Specialty>> specialties) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String?>(
          key: const Key('history-filter-status'),
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
            onChanged: (value) => setState(() {
              _specialtyId = value;
              _page = 0;
            }),
          ),
        ),
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
        TextField(
          key: const Key('history-filter-doctor'),
          controller: _doctorController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'ID del médico',
            helperText: 'Ingresá el ID del médico asociado a la consulta.',
          ),
          onSubmitted: (_) => _applyFilters(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<AppointmentHistoryOrder>(
                key: const Key('history-filter-order'),
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
            FilledButton(
              key: const Key('history-apply-filters'),
              onPressed: _applyFilters,
              child: const Text('Aplicar filtros'),
            ),
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
        Text(message, key: const Key('history-error')),
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
          _AppointmentCard(appointment: appointment),
        Row(
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
              onPressed: result.hasNext
                  ? () => setState(() => _page += 1)
                  : null,
              child: const Text('Siguiente'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment});

  final Appointment appointment;

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
        onTap: () => context.push('$kAppointmentsPath/${value.id}'),
      ),
    );
  }
}
