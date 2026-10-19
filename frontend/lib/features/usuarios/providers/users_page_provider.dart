import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_page.dart';
import 'user_filters_controller.dart';
import 'user_repository_provider.dart';

/// La página del padrón que corresponde a los filtros aplicados. Se vuelve a
/// pedir al servidor cada vez que cambian; el alta de un usuario la invalida.
final usersPageProvider = FutureProvider.autoDispose<UserPage>((ref) async {
  final filters = ref.watch(userFiltersControllerProvider);
  final repository = await ref.watch(userRepositoryProvider.future);
  return repository.listUsers(filters);
});
