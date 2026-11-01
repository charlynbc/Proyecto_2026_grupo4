import '../../features/agenda/models/appointment.dart';
import '../../features/agenda/models/available_number.dart';
import '../../features/agenda/models/referral.dart';
import 'datos_prueba.dart';
import 'fake_admin_database.dart';

/// Las consultas con que arranca la socia de los datos de prueba (Ana
/// Rodríguez), para que Mis consultas tenga qué mostrar con
/// `USE_FAKES=true`. Las fechas son relativas a [today] (la clave de día de
/// Uruguay), así que no envejecen:
///
/// - una agendada de Dermatología, dentro de 12 días;
/// - una cancelada por el socio de Medicina General, hace 11 días;
/// - una atendida de Medicina General, hace 31 días.
///
/// Las especialidades y los consultorios salen de [admin], para que sus ids
/// coincidan con los del catálogo que ven los filtros. [newId] reparte los ids
/// de las consultas, así las que se agenden después siguen la numeración.
List<Appointment> seedMemberAppointments({
  required DateTime today,
  required FakeAdminDatabase admin,
  required int Function() newId,
}) {
  final dermatology = admin.specialties.firstWhere(
    (s) =>
        FakeAdminDatabase.normalize(s.name) ==
        FakeAdminDatabase.normalize('Dermatología'),
  );
  final general = admin.specialties.firstWhere(
    (s) =>
        FakeAdminDatabase.normalize(s.name) ==
        FakeAdminDatabase.normalize('Medicina General'),
  );
  final clinic12 = admin.clinics.firstWhere((c) => c.name == 'Consultorio 12');
  final clinic3 = admin.clinics.firstWhere((c) => c.name == 'Consultorio 3');
  final acosta = _doctorRef(3);
  final mendez = _doctorRef(1);

  DateTime day(int offset) => today.add(Duration(days: offset));
  DateTime noon(int offset) => day(offset).add(const Duration(hours: 12));

  return [
    Appointment(
      id: newId(),
      status: 'AGENDADA',
      date: day(12),
      number: 2,
      startMinutes: 9 * 60 + 30,
      endMinutes: 10 * 60,
      doctor: acosta,
      specialty: dermatology,
      clinic: clinic12,
      referralId: null,
      bookedAt: noon(-3),
      cancelledAt: null,
      cancellationReason: null,
    ),
    Appointment(
      id: newId(),
      status: 'CANCELADA_SOCIO',
      date: day(-11),
      number: 1,
      startMinutes: 8 * 60,
      endMinutes: 8 * 60 + 30,
      doctor: mendez,
      specialty: general,
      clinic: clinic3,
      referralId: null,
      bookedAt: noon(-20),
      cancelledAt: noon(-13),
      cancellationReason: null,
    ),
    Appointment(
      id: newId(),
      status: 'ATENDIDA',
      date: day(-31),
      number: 3,
      startMinutes: 14 * 60,
      endMinutes: 14 * 60 + 30,
      doctor: mendez,
      specialty: general,
      clinic: clinic3,
      referralId: null,
      bookedAt: noon(-40),
      cancelledAt: null,
      cancellationReason: null,
    ),
  ];
}

/// Los pases de Cardiología de la socia de prueba, con fechas relativas a
/// [today] (la clave de día de Uruguay) como las consultas sembradas:
///
/// - el pase 1, emitido hace 5 días y vigente hasta dentro de 25: cubre todos
///   los números de Cardiología que genera `TestData` (hoy más 20 días);
/// - el pase 2, emitido hace 40 días y vencido hace 2.
///
/// Ninguno está usado por las consultas sembradas.
List<Referral> seedMemberReferrals({
  required DateTime today,
  required FakeAdminDatabase admin,
}) {
  final cardiology = admin.specialties.firstWhere(
    (s) =>
        FakeAdminDatabase.normalize(s.name) ==
        FakeAdminDatabase.normalize('Cardiología'),
  );

  DateTime day(int offset) => today.add(Duration(days: offset));
  DateTime noon(int offset) => day(offset).add(const Duration(hours: 12));

  return [
    Referral(
      id: 1,
      specialty: cardiology,
      issuedAt: noon(-5),
      expiresOn: day(25),
    ),
    Referral(
      id: 2,
      specialty: cardiology,
      issuedAt: noon(-40),
      expiresOn: day(-2),
    ),
  ];
}

/// El médico de los datos de prueba con ese [id], como lo ve la agenda
/// ("Dra. Florencia Acosta" es nombre `Florencia` y apellido `Acosta`).
DoctorRef _doctorRef(int id) {
  final doctor = TestData.doctors.firstWhere((d) => d.id == id);
  final names = doctor.name.replaceFirst(RegExp(r'^Dra?\. '), '').split(' ');
  return DoctorRef(
    id: doctor.id,
    firstName: names.first,
    lastName: names.skip(1).join(' '),
  );
}
