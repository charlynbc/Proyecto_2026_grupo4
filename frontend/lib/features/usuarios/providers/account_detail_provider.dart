import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_detail.dart';
import 'user_correction_repository_provider.dart';

/// El detalle de la cuenta [id] (contrato, fila 68), para precargar la
/// pantalla de corrección. Sin reintento automático: la pantalla avisa y
/// ofrece "Reintentar".
final accountDetailProvider = FutureProvider.autoDispose
    .family<AccountDetail, int>((ref, id) async {
      final repository = await ref.watch(
        userCorrectionRepositoryProvider.future,
      );
      return repository.fetch(id);
    }, retry: (_, _) => null);
