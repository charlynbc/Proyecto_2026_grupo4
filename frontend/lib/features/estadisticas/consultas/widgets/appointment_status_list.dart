import 'package:flutter/material.dart';

import '../models/appointment_statistics.dart';

/// Los siete estados con su cantidad, en el orden fijo de la pantalla. Va en
/// una `Column` y no en una `ListView` porque la pantalla ya hace scroll.
class AppointmentStatusList extends StatelessWidget {
  const AppointmentStatusList({super.key, required this.statistics});

  final AppointmentStatistics statistics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < kStatisticsStatusOrder.length; i++)
          Card(
            key: Key('stats-state-row-$i'),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      statisticsStatusLabel(kStatisticsStatusOrder[i]),
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${statistics.counts[kStatisticsStatusOrder[i]]}',
                    style: theme.textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
