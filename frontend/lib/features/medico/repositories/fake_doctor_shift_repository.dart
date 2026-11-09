import '../models/doctor_shift.dart';
import 'doctor_shift_repository.dart';

/// Implementación en memoria para `USE_FAKES=true`. Nunca se usa contra la API.
///
/// Las consultas canceladas salen de la lista: el número queda libre y el
/// turno baja un reservado.
class FakeDoctorShiftRepository implements DoctorShiftRepository {
  final Set<int> _cancelled = {};

  static const _patients = [
    DoctorPatient(ci: '1.111.111-1', name: 'Ana', lastName: 'Pérez'),
    DoctorPatient(ci: '2.222.222-2', name: 'Luis', lastName: 'Gómez'),
  ];

  @override
  Future<List<DoctorShift>> listShifts(String date) async => [
    DoctorShift(
      id: 1,
      date: date,
      startTime: '09:00',
      endTime: '10:00',
      specialtyName: 'Medicina General',
      clinicName: 'Consultorio 1',
      status: 'ACTIVO',
      numbersCount: 3,
      reservedCount: 2 - _cancelled.length,
    ),
  ];

  @override
  Future<DoctorShiftNumbers> listNumbers(
    int shiftId, {
    bool? arrived,
    DoctorNumbersOrder order = DoctorNumbersOrder.time,
    bool ascending = true,
  }) async {
    var items = [
      _cancelled.contains(10)
          ? const DoctorShiftNumber(
              numberId: 1,
              number: 1,
              startTime: '09:00',
              endTime: '09:20',
            )
          : DoctorShiftNumber(
              numberId: 1,
              number: 1,
              startTime: '09:00',
              endTime: '09:20',
              appointmentId: 10,
              appointmentStatus: 'AGENDADA',
              patient: _patients[0],
              arrivedAt: DateTime.utc(2026, 1, 1, 12, 40),
            ),
      _cancelled.contains(11)
          ? const DoctorShiftNumber(
              numberId: 2,
              number: 2,
              startTime: '09:20',
              endTime: '09:40',
            )
          : DoctorShiftNumber(
              numberId: 2,
              number: 2,
              startTime: '09:20',
              endTime: '09:40',
              appointmentId: 11,
              appointmentStatus: 'AGENDADA',
              patient: _patients[1],
            ),
      const DoctorShiftNumber(
        numberId: 3,
        number: 3,
        startTime: '09:40',
        endTime: '10:00',
      ),
    ];
    if (arrived != null) {
      items = [
        for (final item in items)
          if (item.isReserved && item.hasArrived == arrived) item,
      ];
    }
    if (!ascending) items = items.reversed.toList();
    return DoctorShiftNumbers(shiftId: shiftId, items: items);
  }

  /// La consulta [appointmentId] ya fue cancelada en esta memoria.
  bool isCancelled(int appointmentId) => _cancelled.contains(appointmentId);

  /// Marca la consulta [appointmentId] como cancelada. El número pasa a libre.
  void cancelAppointment(int appointmentId) {
    _cancelled.add(appointmentId);
  }
}
