import 'package:flutter/material.dart';

import '../models/specialty_demand.dart';

/// El detalle del gráfico: una fila por especialidad con su cantidad. Va en
/// una `Column` y no en una `ListView` porque la pantalla ya hace scroll.
class SpecialtyDemandList extends StatelessWidget {
  const SpecialtyDemandList({super.key, required this.items});

  final List<SpecialtyDemandItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Card(
            key: Key('stats-row-$i'),
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].specialty.name,
                          style: theme.textTheme.titleMedium,
                        ),
                        if (items[i].specialty.requiresReferral)
                          Text(
                            'Requiere pase',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('${items[i].count}', style: theme.textTheme.titleLarge),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
