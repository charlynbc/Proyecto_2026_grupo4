import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/professional.dart';
import 'agenda_repository_provider.dart';

final professionalsProvider = FutureProvider<List<Professional>>((ref) async {
  final repository = await ref.watch(agendaRepositoryProvider.future);
  return repository.listProfessionals();
});
