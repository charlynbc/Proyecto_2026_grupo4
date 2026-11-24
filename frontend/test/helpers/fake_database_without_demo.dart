import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_database.dart';
import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// La base falsa de la app (`fakeDatabaseProvider`) con la semilla de tres
/// consultas, sin las de demostración de `cancelable` (101 y 102). La app con
/// `USE_FAKES` las trae; los tests que cuentan consultas o que agendan (la
/// socia llegaría al máximo de tres agendadas) usan esta para conservar su
/// intención.
final Override fakeDatabaseWithoutDemo = fakeDatabaseProvider.overrideWith(
  (ref) => FakeDatabase(
    today: UruguayTime.today(),
    admin: ref.watch(fakeAdminDatabaseProvider),
  ),
);
