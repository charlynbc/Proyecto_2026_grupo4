import 'dart:async';

import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/forms/submit_state.dart';
import 'package:agenda_medica/core/network/api_exception.dart';
import 'package:agenda_medica/features/usuarios/models/account_detail.dart';
import 'package:agenda_medica/features/usuarios/models/user_account.dart';
import 'package:agenda_medica/features/usuarios/models/user_filters.dart';
import 'package:agenda_medica/features/usuarios/models/user_page.dart';
import 'package:agenda_medica/features/usuarios/providers/account_detail_provider.dart';
import 'package:agenda_medica/features/usuarios/providers/correct_user_controller.dart';
import 'package:agenda_medica/features/usuarios/providers/user_correction_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/providers/user_filters_controller.dart';
import 'package:agenda_medica/features/usuarios/providers/user_repository_provider.dart';
import 'package:agenda_medica/features/usuarios/providers/users_page_provider.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_correction_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/fake_user_repository.dart';
import 'package:agenda_medica/features/usuarios/repositories/user_correction_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Users extends FakeUserRepository {
  _Users(super.db) : super(latency: Duration.zero);

  int listCalls = 0;

  @override
  Future<UserPage> listUsers(UserFilters filters) {
    listCalls++;
    return super.listUsers(filters);
  }
}

class _Corrections implements UserCorrectionRepository {
  _Corrections(this._delegate);

  final UserCorrectionRepository _delegate;
  final corrected = <(int, AccountCorrection)>[];
  int fetchCalls = 0;
  Completer<void>? gate;
  Object? error;

  @override
  Future<AccountDetail> fetch(int id) {
    fetchCalls++;
    return _delegate.fetch(id);
  }

  @override
  Future<AccountDetail> correct(int id, AccountCorrection changes) async {
    corrected.add((id, changes));
    await gate?.future;
    if (error != null) throw error!;
    return _delegate.correct(id, changes);
  }
}

({ProviderContainer container, _Users users, _Corrections corrections})
_setup() {
  final db = FakeAdminDatabase();
  final users = _Users(db);
  final corrections = _Corrections(
    FakeUserCorrectionRepository(db, latency: Duration.zero),
  );
  final container = ProviderContainer(
    overrides: [
      userRepositoryProvider.overrideWith((ref) async => users),
      userCorrectionRepositoryProvider.overrideWith((ref) async => corrections),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, users: users, corrections: corrections);
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('el detalle se pide por id', () async {
    final s = _setup();

    final detail = await s.container.read(accountDetailProvider(4).future);

    expect(detail.ci, '34567894');
    expect(s.corrections.fetchCalls, 1);
  });

  test('al guardar bien, queda en done y manda lo que se le pasó', () async {
    final s = _setup();
    final sub = s.container.listen(correctUserControllerProvider, (_, _) {});
    addTearDown(sub.close);

    await s.container
        .read(correctUserControllerProvider.notifier)
        .correct(4, const AccountCorrection(phone1: '091111222'));

    expect(
      s.container.read(correctUserControllerProvider).status,
      SubmitStatus.done,
    );
    expect(s.corrections.corrected.single.$1, 4);
    expect(s.corrections.corrected.single.$2.toJson(), {
      'telefono1': '091111222',
    });
  });

  test(
    'al guardar bien se vuelve a pedir el padrón sin tocar los filtros',
    () async {
      final s = _setup();
      final filters = s.container.read(userFiltersControllerProvider.notifier);
      filters.search(status: AccountStatus.active);
      filters.sortBy(UserOrder.createdAt, ascending: false);
      filters.goToPage(1);
      final sub = s.container.listen(usersPageProvider, (_, _) {});
      addTearDown(sub.close);
      await s.container.read(usersPageProvider.future);
      final callsBefore = s.users.listCalls;
      final controllerSub = s.container.listen(
        correctUserControllerProvider,
        (_, _) {},
      );
      addTearDown(controllerSub.close);

      await s.container
          .read(correctUserControllerProvider.notifier)
          .correct(4, const AccountCorrection(phone1: '091111222'));
      await s.container.read(usersPageProvider.future);

      expect(s.users.listCalls, callsBefore + 1);
      final filtersAfter = s.container.read(userFiltersControllerProvider);
      expect(filtersAfter.status, AccountStatus.active);
      expect(filtersAfter.order, UserOrder.createdAt);
      expect(filtersAfter.ascending, isFalse);
      expect(filtersAfter.page, 1);
    },
  );

  test('al guardar bien se vuelve a pedir el detalle', () async {
    final s = _setup();
    final detailSub = s.container.listen(accountDetailProvider(4), (_, _) {});
    addTearDown(detailSub.close);
    await s.container.read(accountDetailProvider(4).future);
    final controllerSub = s.container.listen(
      correctUserControllerProvider,
      (_, _) {},
    );
    addTearDown(controllerSub.close);

    await s.container
        .read(correctUserControllerProvider.notifier)
        .correct(4, const AccountCorrection(phone1: '091111222'));
    final detail = await s.container.read(accountDetailProvider(4).future);

    expect(s.corrections.fetchCalls, 2);
    expect(detail.phone1, '091111222');
  });

  test('un rechazo tipado deja el motivo y el mensaje del servidor', () async {
    final s = _setup();
    final sub = s.container.listen(correctUserControllerProvider, (_, _) {});
    addTearDown(sub.close);
    s.corrections.error = const UserCorrectionException(
      UserCorrectionFailure.ciInUse,
      'Esa cédula ya pertenece a otra persona.',
    );

    await s.container
        .read(correctUserControllerProvider.notifier)
        .correct(4, const AccountCorrection(ci: '45678905'));

    final state = s.container.read(correctUserControllerProvider);
    expect(state.status, SubmitStatus.error);
    expect(state.failure, UserCorrectionFailure.ciInUse);
    expect(state.errorMessage, 'Esa cédula ya pertenece a otra persona.');
  });

  test('un error que no es tipado es other con su mensaje', () async {
    final s = _setup();
    final sub = s.container.listen(correctUserControllerProvider, (_, _) {});
    addTearDown(sub.close);
    s.corrections.error = const ApiException('Sin conexión.');

    await s.container
        .read(correctUserControllerProvider.notifier)
        .correct(4, const AccountCorrection(phone1: '091111222'));

    final state = s.container.read(correctUserControllerProvider);
    expect(state.failure, UserCorrectionFailure.other);
    expect(state.errorMessage, 'Sin conexión.');
  });

  test('si la cuenta ya no existe se vuelve a pedir el padrón', () async {
    final s = _setup();
    final usersSub = s.container.listen(usersPageProvider, (_, _) {});
    addTearDown(usersSub.close);
    await s.container.read(usersPageProvider.future);
    final callsBefore = s.users.listCalls;
    final sub = s.container.listen(correctUserControllerProvider, (_, _) {});
    addTearDown(sub.close);
    s.corrections.error = const UserCorrectionException(
      UserCorrectionFailure.notFound,
      'No encontramos esa cuenta.',
    );

    await s.container
        .read(correctUserControllerProvider.notifier)
        .correct(4, const AccountCorrection(phone1: '091111222'));
    await s.container.read(usersPageProvider.future);

    expect(s.users.listCalls, callsBefore + 1);
  });

  test('un rechazo no vuelve a pedir el padrón', () async {
    final s = _setup();
    final usersSub = s.container.listen(usersPageProvider, (_, _) {});
    addTearDown(usersSub.close);
    await s.container.read(usersPageProvider.future);
    final callsBefore = s.users.listCalls;
    final sub = s.container.listen(correctUserControllerProvider, (_, _) {});
    addTearDown(sub.close);
    s.corrections.error = const UserCorrectionException(
      UserCorrectionFailure.ciInUse,
      'Esa cédula ya pertenece a otra persona.',
    );

    await s.container
        .read(correctUserControllerProvider.notifier)
        .correct(4, const AccountCorrection(ci: '45678905'));
    await _settle();

    expect(s.users.listCalls, callsBefore);
  });

  test('un segundo envío mientras guarda no hace otra llamada', () async {
    final s = _setup();
    final sub = s.container.listen(correctUserControllerProvider, (_, _) {});
    addTearDown(sub.close);
    s.corrections.gate = Completer<void>();
    final controller = s.container.read(correctUserControllerProvider.notifier);

    final first = controller.correct(
      4,
      const AccountCorrection(phone1: '091111222'),
    );
    await _settle();
    final second = controller.correct(
      4,
      const AccountCorrection(phone1: '091111222'),
    );
    s.corrections.gate!.complete();
    await Future.wait([first, second]);

    expect(s.corrections.corrected, hasLength(1));
    expect(
      s.container.read(correctUserControllerProvider).status,
      SubmitStatus.done,
    );
  });

  test(
    'clearError saca el error y no toca un estado que no es de error',
    () async {
      final s = _setup();
      final sub = s.container.listen(correctUserControllerProvider, (_, _) {});
      addTearDown(sub.close);
      final controller = s.container.read(
        correctUserControllerProvider.notifier,
      );
      s.corrections.error = const UserCorrectionException(
        UserCorrectionFailure.validation,
        'Revisá los datos.',
      );

      await controller.correct(4, const AccountCorrection(phone1: '091111222'));
      expect(
        s.container.read(correctUserControllerProvider).status,
        SubmitStatus.error,
      );
      controller.clearError();

      expect(
        s.container.read(correctUserControllerProvider).status,
        SubmitStatus.idle,
      );
      expect(s.container.read(correctUserControllerProvider).failure, isNull);
    },
  );
}
