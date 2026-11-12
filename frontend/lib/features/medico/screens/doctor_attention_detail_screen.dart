import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/centered_content.dart';
import '../providers/doctor_attentions_provider.dart';

class DoctorAttentionDetailScreen extends ConsumerWidget {
  const DoctorAttentionDetailScreen({required this.id, super.key});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Detalle de atención')),
    body: CenteredContent(
      maxWidth: 900,
      child: ref
          .watch(doctorAttentionDetailProvider(id))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(apiMessageOf(e)),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(doctorAttentionDetailProvider(id)),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
            data: (a) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatUiDate(a.attendedOn),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(a.patient.fullName),
                        Text('CI ${a.patient.ci}'),
                        Text(a.specialty.name),
                        const SizedBox(height: 16),
                        section(context, 'Afección', a.condition),
                        if (a.treatment?.trim().isNotEmpty == true)
                          section(context, 'Tratamiento', a.treatment!),
                        if (a.observations?.trim().isNotEmpty == true)
                          section(context, 'Observaciones', a.observations!),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pases emitidos',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (a.referrals.isEmpty)
                  const Text('No se emitieron pases en esta atención.')
                else
                  for (final r in a.referrals)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.specialty.name),
                            Text('Vence el ${formatUiDate(r.expiresOn)}'),
                          ],
                        ),
                      ),
                    ),
              ],
            ),
          ),
    ),
  );
  Widget section(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        Text(value),
      ],
    ),
  );
}
