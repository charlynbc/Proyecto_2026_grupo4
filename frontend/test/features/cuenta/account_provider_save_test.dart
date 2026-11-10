import 'dart:async';

import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/cuenta/models/account.dart';
import 'package:agenda_medica/features/cuenta/models/account_changes.dart';
import 'package:agenda_medica/features/cuenta/providers/account_provider.dart';
import 'package:agenda_medica/features/cuenta/providers/account_repository_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_test_support.dart';

class _GatedRepository extends RecordingAccountRepository {
  final saveGate = Completer<void>();
  int updates = 0;

  @override
  Future<Account> update(AccountChanges changes) async {
    updates++;
    await saveGate.future;
    return lucia();
  }
}

void main() {
  test('el provider rechaza otro save mientras guarda', () async {
    final repo = _GatedRepository();
    final container = ProviderContainer(
      overrides: [accountRepositoryProvider.overrideWith((ref) async => repo)],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(accountProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(accountProvider.future);

    final notifier = container.read(accountProvider.notifier);
    final first = notifier.save(
      const AccountChanges(address: 'Av. Italia 1234'),
    );
    final blocked = expectLater(
      notifier.save(const AccountChanges(phone1: '099000111')),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Ya hay cambios que se están guardando.',
        ),
      ),
    );
    repo.saveGate.complete();
    await first;
    await blocked;
    expect(repo.updates, 1);
  });
}
