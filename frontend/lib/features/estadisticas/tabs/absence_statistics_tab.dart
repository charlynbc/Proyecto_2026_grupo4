import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/centered_content.dart';
import '../absences/models/absence_statistics.dart';
import '../absences/providers/absence_statistics_provider.dart';
import '../absences/repositories/absence_statistics_repository.dart';
import '../widgets/period_filter.dart';
import '../widgets/period_label.dart';

const String _sessionExpiredMessage =
    'Tu sesión venció. Iniciá sesión nuevamente.';
const String _periodErrorMessage =
    'La fecha Desde no puede ser posterior a la fecha Hasta.';

/// Pestaña "Inasistencias" de las estadísticas del administrador (RF-42).
///
/// Al abrir consulta por especialidad, sin fechas. Cambiar la agrupación
/// vuelve a pedir enseguida. Las fechas se mandan solo al tocar Consultar, y
/// el período que se muestra es el de la respuesta.
class AbsenceStatisticsTab extends ConsumerStatefulWidget {
  const AbsenceStatisticsTab({super.key});

  @override
  ConsumerState<AbsenceStatisticsTab> createState() =>
      _AbsenceStatisticsTabState();
}

class _AbsenceStatisticsTabState extends ConsumerState<AbsenceStatisticsTab> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  /// Lo que eligió el usuario; lo que llena la respuesta no entra acá.
  DateTime? _chosenFrom;
  DateTime? _chosenTo;

  /// La consulta en pantalla, para que "Reintentar" la repita igual.
  DateTime? _requestedFrom;
  DateTime? _requestedTo;

  AbsenceGrouping _grouping = AbsenceGrouping.specialty;
  AbsenceStatistics? _result;
  String? _error;
  String? _periodError;
  bool _loading = true;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _fetch(null, null);
  }

  @override
  void dispose() {
    _fromController.dispose();
    _toController.dispose();
    super.dispose();
  }

  Future<void> _fetch(DateTime? from, DateTime? to) async {
    _requestedFrom = from;
    _requestedTo = to;
    final grouping = _grouping;
    final id = ++_requestId;
    if (!_loading || _error != null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repository = await ref.read(
        absenceStatisticsRepositoryProvider.future,
      );
      final result = await repository.statistics(
        from: from,
        to: to,
        grouping: grouping,
      );
      if (!mounted || id != _requestId) return;
      _fromController.text = formatUiDate(result.from);
      _toController.text = formatUiDate(result.to);
      setState(() {
        _result = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = _messageOf(error);
        _loading = false;
      });
    }
  }

  static String _messageOf(Object error) {
    if (error is AbsenceStatisticsException) {
      return switch (error.failure) {
        AbsenceStatisticsFailure.unauthenticated => _sessionExpiredMessage,
        AbsenceStatisticsFailure.forbidden =>
          kAbsenceStatisticsForbiddenMessage,
        AbsenceStatisticsFailure.validation => error.message,
        AbsenceStatisticsFailure.other => kApiGenericMessage,
      };
    }
    return kApiGenericMessage;
  }

  void _consult() {
    final from = _chosenFrom;
    final to = _chosenTo;
    if (from != null && to != null && from.isAfter(to)) {
      setState(() => _periodError = _periodErrorMessage);
      return;
    }
    setState(() => _periodError = null);
    _fetch(from, to);
  }

  void _selectGrouping(AbsenceGrouping grouping) {
    if (grouping == _grouping) return;
    setState(() => _grouping = grouping);
    _fetch(_chosenFrom, _chosenTo);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return CenteredContent(
      maxWidth: 720,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Agrupar por', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Especialidad'),
                selected: _grouping == AbsenceGrouping.specialty,
                onSelected: _loading
                    ? null
                    : (selected) {
                        if (selected) {
                          _selectGrouping(AbsenceGrouping.specialty);
                        }
                      },
              ),
              ChoiceChip(
                label: const Text('Médico'),
                selected: _grouping == AbsenceGrouping.doctor,
                onSelected: _loading
                    ? null
                    : (selected) {
                        if (selected) {
                          _selectGrouping(AbsenceGrouping.doctor);
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 16),
          PeriodFilter(
            fromController: _fromController,
            toController: _toController,
            onFromChanged: (date) => _chosenFrom = date,
            onToChanged: (date) => _chosenTo = date,
            onConsult: _loading ? null : _consult,
            errorText: _periodError,
          ),
          const SizedBox(height: 24),
          if (_loading)
            const _Loading()
          else if (_error != null)
            _ErrorNotice(
              message: _error!,
              onRetry: () => _fetch(_requestedFrom, _requestedTo),
            )
          else if (result != null)
            _Results(result: result),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    // Un ícono quieto y no un indicador que gira: uno animado no deja
    // asentarse a los tests.
    return const Column(
      key: Key('stats-loading'),
      children: [
        Icon(Icons.hourglass_top, size: 32),
        SizedBox(height: 12),
        Text('Calculando estadísticas'),
      ],
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          message,
          key: const Key('stats-error'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('stats-retry'),
          onPressed: onRetry,
          child: const Text('Reintentar'),
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.result});

  final AbsenceStatistics result;

  @override
  Widget build(BuildContext context) {
    final items = result.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PeriodLabel(from: result.from, to: result.to),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const Text(
            'Sin datos',
            key: Key('stats-empty'),
            textAlign: TextAlign.center,
          )
        else
          for (final item in items) _GroupCard(item: item),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({required this.item});

  final AbsenceGroup item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lastName = item.lastName;
    final title = lastName == null || lastName.isEmpty
        ? item.name
        : '${item.name} $lastName';
    final absences = item.noShow + item.missed;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('$absences de ${item.total}'),
            Text(item.percentageText, style: theme.textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
