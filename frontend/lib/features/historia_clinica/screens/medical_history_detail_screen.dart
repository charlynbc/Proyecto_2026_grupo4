import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/centered_content.dart';
import '../models/medical_history_entry.dart';
import '../providers/medical_history_provider.dart';

/// Información clínica y pases de una atención del socio.
class MedicalHistoryDetailScreen extends ConsumerWidget {
  const MedicalHistoryDetailScreen({required this.id, super.key});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(medicalHistoryDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de atención')),
      body: CenteredContent(
        maxWidth: 900,
        child: detail.when(
          skipLoadingOnRefresh: false,
          skipLoadingOnReload: false,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                apiMessageOf(error),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () =>
                    ref.invalidate(medicalHistoryDetailProvider(id)),
                child: const Text('Reintentar'),
              ),
            ],
          ),
          data: (entry) => _details(context, entry),
        ),
      ),
    );
  }

  Widget _details(BuildContext context, MedicalHistoryEntry entry) {
    final treatment = entry.treatment?.trim();
    final observations = entry.observations?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
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
              ],
            ),
          ),
        ),
        Text('Pases emitidos', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        if (entry.referrals.isEmpty)
          const Text('No se emitieron pases en esta atención.')
        else
          for (final referral in entry.referrals)
            Card(
              key: ValueKey('history-referral-${referral.id}'),
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(referral.specialty.name),
                    const SizedBox(height: 8),
                    Text('Vence el ${formatUiDate(referral.expiresOn)}'),
                  ],
                ),
              ),
            ),
      ],
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
