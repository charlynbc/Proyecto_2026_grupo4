import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/centered_content.dart';
import '../especialidades/models/specialty_demand.dart';
import '../especialidades/providers/specialty_statistics_provider.dart';
import '../especialidades/repositories/specialty_statistics_repository.dart';
import '../widgets/period_filter.dart';
import '../especialidades/widgets/specialty_demand_chart.dart';
import '../especialidades/widgets/specialty_demand_list.dart';

const String _sessionExpiredMessage =
    'Tu sesión venció. Iniciá sesión nuevamente.';
const String _forbiddenMessage =
    'Tu cuenta no tiene permiso para ver las estadísticas.';
const String _periodErrorMessage =
    'La fecha Desde no puede ser posterior a la fecha Hasta.';

/// Pestaña "Demanda por especialidad" de las estadísticas del administrador
/// (RF-39): las consultas agendadas por especialidad en un período.
///
/// Al abrir consulta sin fechas (el servidor usa el mes en curso) y llena
/// Desde y Hasta con lo que devolvió, solo para mostrarlo. Al consultar se
/// mandan únicamente las fechas que el usuario eligió.
class SpecialtyStatisticsTab extends ConsumerStatefulWidget {
  const SpecialtyStatisticsTab({super.key});

  @override
  ConsumerState<SpecialtyStatisticsTab> createState() =>
      _SpecialtyStatisticsTabState();
}

class _SpecialtyStatisticsTabState
    extends ConsumerState<SpecialtyStatisticsTab> {
  final _fromController = TextEditingController();
  final _toController = TextEditingController();

  /// Lo que eligió el usuario; lo que llena la respuesta no entra acá.
  DateTime? _chosenFrom;
  DateTime? _chosenTo;

  /// La consulta en pantalla, para que "Reintentar" la repita igual.
  DateTime? _requestedFrom;
  DateTime? _requestedTo;

  SpecialtyDemand? _demand;
  String? _error;
  String? _periodError;
  bool _loading = true;

  /// Para descartar una respuesta que llega después de otra consulta más nueva.
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
    final id = ++_requestId;
    if (!_loading || _error != null) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final repository = await ref.read(
        specialtyStatisticsRepositoryProvider.future,
      );
      final demand = await repository.demand(from: from, to: to);
      if (!mounted || id != _requestId) return;
      _fromController.text = formatUiDate(demand.from);
      _toController.text = formatUiDate(demand.to);
      setState(() {
        _demand = demand;
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
    if (error is SpecialtyStatisticsException) {
      return switch (error.failure) {
        SpecialtyStatisticsFailure.unauthenticated => _sessionExpiredMessage,
        SpecialtyStatisticsFailure.forbidden => _forbiddenMessage,
        SpecialtyStatisticsFailure.validation => error.message,
        SpecialtyStatisticsFailure.other => kApiGenericMessage,
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

  @override
  Widget build(BuildContext context) {
    final demand = _demand;
    return CenteredContent(
      maxWidth: 720,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          else if (demand != null)
            _Results(demand: demand),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) {
    // Un ícono quieto y no un indicador que gira: uno animado mantiene
    // ocupado al motor de frames y los tests de la pantalla de estadísticas
    // (que no reemplazan el repository) no terminan nunca de asentarse.
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
  const _Results({required this.demand});

  final SpecialtyDemand demand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Total de consultas: ${demand.total}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        if (demand.items.isEmpty)
          const Text(
            'No hay consultas en el período.',
            key: Key('stats-empty'),
            textAlign: TextAlign.center,
          )
        else ...[
          SpecialtyDemandChart(items: demand.items),
          const SizedBox(height: 16),
          SpecialtyDemandList(items: demand.items),
        ],
      ],
    );
  }
}
