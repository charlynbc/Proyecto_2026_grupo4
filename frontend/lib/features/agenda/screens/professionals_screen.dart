import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/centered_content.dart';
import '../providers/professionals_provider.dart';

class ProfessionalsScreen extends ConsumerWidget {
  const ProfessionalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final professionals = ref.watch(professionalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Agenda')),
      body: CenteredContent(
        maxWidth: 600,
        child: professionals.when(
          data: (list) {
            if (list.isEmpty) {
              return const Text('No hay profesionales disponibles.');
            }
            return Column(
              children: [
                for (final professional in list)
                  Card(
                    child: ListTile(
                      title: Text(professional.name),
                      onTap: () => context.go('/agenda/${professional.id}'),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'No pudimos cargar los profesionales. Intentá de nuevo.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(professionalsProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
