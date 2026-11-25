import 'package:agenda_medica/core/fakes/fake_admin_database.dart';
import 'package:agenda_medica/core/fakes/fake_database.dart';
import 'package:agenda_medica/core/fakes/fake_notification_seed.dart';
import 'package:agenda_medica/core/utils/uruguay_time.dart';
import 'package:agenda_medica/features/agenda/models/appointment.dart';
import 'package:agenda_medica/features/historia_clinica/models/medical_history_query.dart';
import 'package:agenda_medica/features/historia_clinica/repositories/fake_medical_history_repository.dart';
import 'package:agenda_medica/features/notificaciones/models/notification_query.dart';
import 'package:agenda_medica/features/notificaciones/repositories/fake_notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// 15/11/2026 12:00 en Uruguay.
final _now = DateTime.utc(2026, 11, 15, 15);

// Lo que dicen las tres consultas del Fake, escrito a mano para el 15/11/2026:
// la agendada es dentro de 12 días, la cancelada por el socio fue hace 11 y la
// atendida hace 31.
const _agendada = (
  id: 1,
  status: 'AGENDADA',
  date: '27/11/2026',
  time: '09:30 - 10:00',
  number: 2,
  specialty: 'Dermatología',
);
const _cancelada = (
  id: 2,
  status: 'CANCELADA_SOCIO',
  date: '04/11/2026',
  time: '08:00 - 08:30',
  number: 1,
  specialty: 'Medicina General',
);
const _atendida = (
  id: 3,
  status: 'ATENDIDA',
  date: '15/10/2026',
  time: '14:00 - 14:30',
  number: 3,
  specialty: 'Medicina General',
);

void main() {
  late List<Appointment> appointments;
  late List<FakeStoredNotification> seed;

  setUp(() {
    appointments = FakeDatabase(
      today: UruguayTime.today(now: _now),
      admin: FakeAdminDatabase(),
    ).appointments;
    seed = fakeNotificationSeed(_now);
  });

  List<FakeStoredNotification> linked() => [
    for (final s in seed)
      if (s.notification.consultaId != null) s,
  ];

  test('las consultas del Fake dicen lo que este test espera', () {
    for (final expected in [_agendada, _cancelada, _atendida]) {
      final a = appointments.singleWhere((x) => x.id == expected.id);
      expect(a.status, expected.status);
      expect(a.number, expected.number);
      expect(a.timeRange, expected.time);
      expect(a.specialty.name, expected.specialty);
    }
  });

  test('cada aviso con consultaId apunta a una consulta que existe', () {
    expect(linked(), isNotEmpty);
    for (final s in linked()) {
      final id = s.notification.consultaId;
      expect(
        appointments.where((a) => a.id == id),
        hasLength(1),
        reason: 'aviso ${s.notification.id} consulta $id',
      );
    }
  });

  test('un aviso con consulta es del socio dueño de esa consulta', () {
    // Las consultas del Fake son de la socia de prueba.
    for (final s in linked()) {
      expect(s.ownerCi, kFakeMemberCi, reason: 'aviso ${s.notification.id}');
    }
  });

  test('los avisos de otro socio no apuntan a la consulta de la socia', () {
    final others = seed.where((s) => s.ownerCi == kFakeOtherMemberCi);
    expect(others, hasLength(3));
    for (final s in others) {
      expect(s.notification.consultaId, isNull);
    }
  });

  test('el estado de la consulta es coherente con el tipo de aviso', () {
    final expected = {
      'AGENDA': 'AGENDADA',
      'RECORDATORIO': 'AGENDADA',
      'CANCELACION': 'CANCELADA_SOCIO',
      'HISTORIA_ACTUALIZADA': 'ATENDIDA',
    };
    for (final s in linked()) {
      final n = s.notification;
      final a = appointments.singleWhere((x) => x.id == n.consultaId);
      expect(a.status, expected[n.type], reason: 'aviso ${n.id} ${n.type}');
    }
  });

  test('cada aviso de historia lleva el atencionId 14, que existe en la '
      'historia falsa con la especialidad de su consulta', () async {
    final history = await FakeMedicalHistoryRepository(latency: Duration.zero)
        .list(const MedicalHistoryQuery());
    final historia = [
      for (final s in seed)
        if (s.notification.type == 'HISTORIA_ACTUALIZADA') s.notification,
    ];

    expect(historia.map((n) => n.id), [3, 8, 13, 18, 23]);
    for (final n in historia) {
      expect(n.atencionId, 14, reason: 'aviso ${n.id}');
      final atencion = history.singleWhere((e) => e.id == n.atencionId);
      final consulta = appointments.singleWhere((a) => a.id == n.consultaId);
      expect(atencion.specialty.name, 'Medicina General');
      expect(
        atencion.specialty.name.toLowerCase(),
        consulta.specialty.name.toLowerCase(),
        reason: 'aviso ${n.id}',
      );
    }
  });

  test('los avisos que no son de historia no llevan atencionId', () {
    for (final s in seed) {
      if (s.notification.type == 'HISTORIA_ACTUALIZADA') continue;
      expect(
        s.notification.atencionId,
        isNull,
        reason: 'aviso ${s.notification.id} ${s.notification.type}',
      );
    }
  });

  test('los avisos de suspensión van sin consulta', () {
    final suspensions = seed.where((s) => s.notification.type == 'SUSPENSION');
    expect(suspensions, isNotEmpty);
    for (final s in suspensions) {
      expect(s.notification.consultaId, isNull);
    }
  });

  test('el texto repite la fecha, el horario, el número y la especialidad de '
      'su consulta', () {
    final byId = {
      for (final e in [_agendada, _cancelada, _atendida]) e.id: e,
    };
    for (final s in linked()) {
      final n = s.notification;
      final e = byId[n.consultaId]!;
      for (final part in [e.date, e.time, 'número ${e.number}', e.specialty]) {
        expect(n.content, contains(part), reason: 'aviso ${n.id}: $part');
      }
    }
  });

  test('ningún texto dice que la consulta es mañana', () {
    for (final s in seed) {
      expect(s.notification.content, isNot(contains('Mañana')));
      expect(s.notification.content, isNot(contains('mañana')));
    }
  });

  test('el texto exacto de cada tipo con consulta', () {
    String content(String type) => seed
        .firstWhere(
          (s) =>
              s.notification.type == type && s.notification.consultaId != null,
        )
        .notification
        .content;

    expect(
      content('AGENDA'),
      'Tu consulta de Dermatología quedó agendada para el 27/11/2026. '
      'Horario: 09:30 - 10:00 (número 2).',
    );
    expect(
      content('RECORDATORIO'),
      'Tenés consulta de Dermatología el 27/11/2026. '
      'Horario: 09:30 - 10:00 (número 2).',
    );
    expect(
      content('CANCELACION'),
      'Tu consulta de Medicina General del 04/11/2026 fue cancelada a tu '
      'solicitud. Horario: 08:00 - 08:30 (número 1).',
    );
    expect(
      content('HISTORIA_ACTUALIZADA'),
      'Tu historia clínica fue actualizada tras tu consulta de Medicina '
      'General del 15/10/2026. Horario: 14:00 - 14:30 (número 3).',
    );
  });

  test('el texto de suspensión no afirma fecha, horario ni número', () {
    final suspension = seed.firstWhere(
      (s) => s.notification.type == 'SUSPENSION',
    );
    expect(
      suspension.notification.content,
      'Una de tus consultas fue cancelada por la institución. Motivo: el '
      'médico no atiende ese día.',
    );
  });

  test('el conteo y el orden no cambian: 26 avisos, del 26 al 1', () async {
    final page = await FakeNotificationRepository(
      latency: Duration.zero,
      now: () => _now,
    ).list(const NotificationQuery(size: 100));

    expect(page.total, 26);
    expect(
      [for (final n in page.items) n.id],
      [for (var id = 26; id >= 1; id--) id],
    );
  });
}
