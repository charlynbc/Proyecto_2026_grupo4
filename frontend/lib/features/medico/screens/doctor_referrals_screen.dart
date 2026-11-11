import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/ui_date.dart';
import '../../../core/utils/uruguay_time.dart';
import '../../auth/widgets/logout_button.dart';
import '../models/issued_referral.dart';
import '../models/issued_referral_query.dart';
import '../providers/issued_referrals_provider.dart';

final DateFormat _issuedFormat = DateFormat('dd/MM/yyyy HH:mm');

/// Los pases que emitió el médico (RF-26), con filtro por situación y orden.
/// Cada cambio vuelve a consultar al instante.
class DoctorReferralsScreen extends ConsumerWidget {
  const DoctorReferralsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(issuedReferralFiltersProvider);
    final referrals = ref.watch(issuedReferralsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pases emitidos'),
        actions: const [LogoutButton()],
      ),
      // Alineado arriba (como Novedades): con `CenteredContent` los controles
      // se centrarían en vertical y se moverían al cambiar de filtro.
      body: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Filters(query: query),
                const SizedBox(height: 16),
                referrals.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) => _ErrorMessage(
                    message: apiMessageOf(error),
                    onRetry: () => ref.invalidate(issuedReferralsProvider),
                  ),
                  data: (items) => items.isEmpty
                      ? Text(
                          query.status == null
                              ? 'Todavía no emitiste pases.'
                              : 'No hay pases con esa situación.',
                          key: const Key('referrals-empty'),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final referral in items)
                              _ReferralCard(referral: referral),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Filters extends ConsumerWidget {
  const _Filters({required this.query});

  final IssuedReferralQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(issuedReferralFiltersProvider.notifier);
    final ascending = query.direction == IssuedReferralDirection.ascending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const Key('referrals-filter-all'),
              label: const Text('Todos'),
              selected: query.status == null,
              onSelected: (_) => controller.setStatus(null),
            ),
            ChoiceChip(
              key: const Key('referrals-filter-available'),
              label: const Text('Disponibles'),
              selected: query.status == ReferralStatus.available,
              onSelected: (_) => controller.setStatus(ReferralStatus.available),
            ),
            ChoiceChip(
              key: const Key('referrals-filter-used'),
              label: const Text('Utilizados'),
              selected: query.status == ReferralStatus.used,
              onSelected: (_) => controller.setStatus(ReferralStatus.used),
            ),
            ChoiceChip(
              key: const Key('referrals-filter-expired'),
              label: const Text('Vencidos'),
              selected: query.status == ReferralStatus.expired,
              onSelected: (_) => controller.setStatus(ReferralStatus.expired),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Ordenar por'),
            DropdownButton<IssuedReferralOrder>(
              key: const Key('referrals-order'),
              value: query.order,
              items: [
                for (final order in IssuedReferralOrder.values)
                  DropdownMenuItem(value: order, child: Text(order.label)),
              ],
              onChanged: (order) {
                if (order != null) controller.setOrder(order);
              },
            ),
            OutlinedButton.icon(
              key: const Key('referrals-direction'),
              onPressed: () => controller.setDirection(
                ascending
                    ? IssuedReferralDirection.descending
                    : IssuedReferralDirection.ascending,
              ),
              icon: Icon(ascending ? Icons.arrow_upward : Icons.arrow_downward),
              label: Text(ascending ? 'Ascendente' : 'Descendente'),
            ),
          ],
        ),
      ],
    );
  }
}

class _ErrorMessage extends StatelessWidget {
  const _ErrorMessage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          key: const Key('referrals-error'),
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          key: const Key('referrals-retry'),
          onPressed: onRetry,
          child: const Text('Reintentar'),
        ),
      ],
    );
  }
}

class _ReferralCard extends StatelessWidget {
  const _ReferralCard({required this.referral});

  final IssuedReferral referral;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final issued = UruguayTime.toUruguay(referral.issuedAt);
    final (background, foreground) = switch (referral.status) {
      ReferralStatus.available => (
        colors.secondaryContainer,
        colors.onSecondaryContainer,
      ),
      ReferralStatus.used => (colors.surfaceContainerHighest, colors.onSurface),
      ReferralStatus.expired => (
        colors.errorContainer,
        colors.onErrorContainer,
      ),
    };
    return Card(
      key: Key('referral-${referral.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${referral.patient.fullName} · CI ${referral.patient.ci}',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text('Especialidad de destino: ${referral.destination.name}'),
            Text('Emitido el ${_issuedFormat.format(issued)}'),
            Text('Vence el ${formatUiDate(referral.expiresOn)}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                referral.status.label,
                key: Key('referral-status-${referral.id}'),
                style: textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
