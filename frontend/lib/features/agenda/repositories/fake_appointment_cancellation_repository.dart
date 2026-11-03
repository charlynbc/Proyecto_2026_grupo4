import '../../../core/fakes/fake_database.dart';
import '../models/cancellation_result.dart';
import 'appointment_cancellation_repository.dart';

class FakeAppointmentCancellationRepository
    implements AppointmentCancellationRepository {
  FakeAppointmentCancellationRepository(
    this._db, {
    this.latency = const Duration(milliseconds: 300),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final FakeDatabase _db;
  final Duration latency;
  final DateTime Function() _clock;

  @override
  Future<CancellationResult> cancel(int id) {
    throw UnimplementedError();
  }
}
