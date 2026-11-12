import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/router/app_router.dart' show kDoctorShiftsPath;
import '../../../core/utils/ui_date.dart';
import '../../historia_clinica/models/medical_history_entry.dart';
import '../providers/doctor_patient_history_provider.dart';

class DoctorPatientHistoryScreen extends ConsumerWidget {
  const DoctorPatientHistoryScreen({
    required this.socioId,
    this.patientName,
    super.key,
  });

  final int socioId;
  final String? patientName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(doctorPatientHistoryProvider(socioId));
    final name = patientName;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historia clínica'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(kDoctorShiftsPath);
            }
          },
        ),
      ),
      // Alineado arriba, justo debajo de la barra: con la historia vacía o con
      // un error no queda flotando en el medio. Un único scroll.
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (name != null && name.isNotEmpty) ...[
                  Text('Paciente: $name'),
                  const SizedBox(height: 12),
                ],
                _notice(context),
                const SizedBox(height: 16),
                history.when(
                  skipLoadingOnRefresh: false,
                  skipLoadingOnReload: false,
                  loading: () => const SizedBox(
                    height: 200,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (error, _) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        apiMessageOf(error),
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        key: const ValueKey('patient-history-retry'),
                        onPressed: () => ref.invalidate(
                          doctorPatientHistoryProvider(socioId),
                        ),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                  data: (entries) {
                    if (entries.isEmpty) {
                      return const Text(
                        'Este paciente todavía no tiene atenciones registradas.',
                        key: ValueKey('patient-history-empty'),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final entry in entries) _entryCard(context, entry),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _notice(BuildContext context) => Container(
    key: const ValueKey('patient-history-notice'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Text(
      'Solo lectura. Podés ver esta historia mientras tengas una consulta '
      'agendada con el paciente que todavía no haya terminado.',
    ),
  );

  Widget _entryCard(BuildContext context, MedicalHistoryEntry entry) {
    final treatment = entry.treatment?.trim();
    final observations = entry.observations?.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              formatUiDate(entry.attendedOn),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(entry.doctorFullName),
            Text(entry.specialty.name),
            const SizedBox(height: 16),
            _section(context, 'Afección', entry.condition),
            if (treatment != null && treatment.isNotEmpty)
              _section(context, 'Tratamiento', treatment),
            if (observations != null && observations.isNotEmpty)
              _section(context, 'Observaciones', observations),
            if (entry.referrals.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                'Pases emitidos',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final referral in entry.referrals)
                Padding(
                  key: ValueKey('history-referral-${referral.id}'),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(referral.specialty.name),
                      const SizedBox(height: 4),
                      Text('Vence el ${formatUiDate(referral.expiresOn)}'),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String label, String content) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(content),
          ],
        ),
      );
}
