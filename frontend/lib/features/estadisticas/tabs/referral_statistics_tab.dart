import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/centered_content.dart';
import '../../especialidades/providers/specialties_provider.dart';
import '../referrals/models/referral_statistics.dart';
import '../referrals/providers/referral_statistics_provider.dart';
import '../widgets/period_filter.dart';
import '../widgets/period_label.dart';

class ReferralStatisticsTab extends ConsumerStatefulWidget {
  const ReferralStatisticsTab({super.key});
  @override
  ConsumerState<ReferralStatisticsTab> createState() =>
      _ReferralStatisticsTabState();
}

class _ReferralStatisticsTabState extends ConsumerState<ReferralStatisticsTab> {
  final fromController = TextEditingController();
  final toController = TextEditingController();
  DateTime? from, to, requestedFrom, requestedTo;
  int? specialtyId;
  ReferralStatistics? result;
  String? error, periodError;
  bool loading = true;
  int request = 0;

  @override
  void initState() {
    super.initState();
    fetch(null, null);
  }

  @override
  void dispose() {
    fromController.dispose();
    toController.dispose();
    super.dispose();
  }

  Future<void> fetch(DateTime? start, DateTime? end) async {
    requestedFrom = start;
    requestedTo = end;
    final id = ++request;
    final specialty = specialtyId;
    if (!loading || error != null) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final repo = await ref.read(referralStatisticsRepositoryProvider.future);
      final data = await repo.statistics(
        from: start,
        to: end,
        specialtyId: specialty,
      );
      if (!mounted || id != request) return;
      fromController.text = formatUiDate(data.from);
      toController.text = formatUiDate(data.to);
      setState(() {
        result = data;
        loading = false;
      });
    } catch (e) {
      if (!mounted || id != request) return;
      setState(() {
        error = apiMessageOf(e);
        loading = false;
      });
    }
  }

  void consult() {
    if (from != null && to != null && from!.isAfter(to!)) {
      setState(
        () => periodError =
            'La fecha Desde no puede ser posterior a la fecha Hasta.',
      );
      return;
    }
    setState(() => periodError = null);
    fetch(from, to);
  }

  @override
  Widget build(BuildContext context) {
    final specialties = ref.watch(specialtiesProvider);
    return CenteredContent(
      maxWidth: 720,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          specialties.when(
            loading: () => const Text('Cargando especialidades'),
            error: (_, _) => Column(
              children: [
                const Text('No se pudieron cargar las especialidades.'),
                TextButton(
                  onPressed: () => ref.invalidate(specialtiesProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
            data: (items) => DropdownButtonFormField<int>(
              initialValue: specialtyId,
              decoration: const InputDecoration(
                labelText: 'Especialidad de origen',
              ),
              items: [
                const DropdownMenuItem<int>(value: null, child: Text('Todas')),
                for (final item in items)
                  DropdownMenuItem(value: item.id, child: Text(item.name)),
              ],
              onChanged: loading
                  ? null
                  : (value) {
                      setState(() => specialtyId = value);
                      fetch(from, to);
                    },
            ),
          ),
          const SizedBox(height: 16),
          PeriodFilter(
            fromController: fromController,
            toController: toController,
            onFromChanged: (value) => from = value,
            onToChanged: (value) => to = value,
            onConsult: loading ? null : consult,
            errorText: periodError,
          ),
          const SizedBox(height: 24),
          if (loading)
            const Text('Calculando estadísticas', key: Key('stats-loading'))
          else if (error != null)
            Column(
              children: [
                Text(error!, key: const Key('stats-error')),
                TextButton(
                  onPressed: () => fetch(requestedFrom, requestedTo),
                  child: const Text('Reintentar'),
                ),
              ],
            )
          else if (result case final data?) ...[
            PeriodLabel(from: data.from, to: data.to),
            const SizedBox(height: 12),
            if (data.items.isEmpty)
              const Text('Sin datos', key: Key('stats-empty'))
            else
              for (final item in data.items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text('Emitidos: ${item.issued}'),
                        Text('Utilizados: ${item.used}'),
                        Text('Disponibles: ${item.available}'),
                        Text('Vencidos: ${item.expired}'),
                        Text('Utilización: ${item.utilization}'),
                      ],
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
