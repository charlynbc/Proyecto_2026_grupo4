import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/widgets/centered_content.dart';
import '../providers/doctor_attentions_provider.dart';
import '../repositories/doctor_attention_repository.dart';
import 'doctor_attention_routes.dart';

class DoctorAttentionDetailScreen extends ConsumerWidget {
  const DoctorAttentionDetailScreen({required this.id, super.key});
  final int id;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Detalle de atención'),
      leading: BackButton(
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go(kDoctorAttentionsPath);
          }
        },
      ),
    ),
    body: CenteredContent(
      maxWidth: 900,
      alignment: Alignment.topCenter,
      child: ref
          .watch(doctorAttentionDetailProvider(id))
          .when(
            skipLoadingOnRefresh: true,
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(apiMessageOf(e)),
                if (e is DoctorAttentionException &&
                    e.failure == DoctorAttentionFailure.notFound)
                  OutlinedButton(
                    onPressed: () => context.go(kDoctorAttentionsPath),
                    child: const Text('Volver a Atenciones'),
                  )
                else
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
                  margin: const EdgeInsets.symmetric(horizontal: 4),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    'Pases emitidos',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (a.referrals.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text('No se emitieron pases en esta atención.'),
                  )
                else
                  for (final r in a.referrals)
                    Card(
                      margin: const EdgeInsets.only(left: 4, right: 4, top: 8),
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
