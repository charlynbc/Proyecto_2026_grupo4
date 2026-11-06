import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/appointment.dart';
import '../models/availability_query.dart';
import '../models/available_number.dart';
import '../models/doctor_with_specialties.dart';
import '../models/referral.dart';
import 'agenda_repository.dart';

/// Implementación real de [AgendaRepository] (contrato #10, #16 y #17). Los
/// rechazos se distinguen por `code`, nunca por el texto del mensaje. Una
/// respuesta mal formada se vuelve el error genérico: no se rellena nada.
class ApiAgendaRepository implements AgendaRepository {
  ApiAgendaRepository(this._dio);

  final Dio _dio;

  @override
  Future<List<AvailableNumber>> listAvailability(
    AvailabilityQuery query,
  ) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiRoutes.availability,
        queryParameters: query.toQueryParameters(),
      );
      return availableNumbersFromJson(
        response.data ?? (throw const ApiException()),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  @override
  Future<List<DoctorWithSpecialties>> listDoctors({int? specialtyId}) async {
    try {
      // Como `Object?`: la respuesta es una lista JSON sin envoltorio, y con
      // otro tipo dio tiraría el cast como una falla de conexión.
      final response = await _dio.get<Object?>(
        ApiRoutes.doctors,
        queryParameters: {'especialidadId': ?specialtyId},
      );
      return doctorsFromJson(response.data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  @override
  Future<List<Referral>> listReferrals() async {
    try {
      // Como `Object?` y no `List`: si el cuerpo no es una lista, dio tira el
      // cast como una falla de conexión, y el servidor sí respondió.
      final response = await _dio.get<Object?>(ApiRoutes.availableReferrals);
      final data = response.data;
      if (data is! List) throw const ApiException();
      return [
        for (final item in data)
          Referral.fromJson(item as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  @override
  Future<Appointment> book({required int numberId, int? referralId}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiRoutes.appointments,
        data: {'numeroId': numberId, 'paseId': referralId},
      );
      return Appointment.fromJson(
        response.data ?? (throw const ApiException()),
      );
    } on DioException catch (e) {
      throw _mapBookingError(e);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  BookingException _mapBookingError(DioException e) {
    final message = ApiException.fromDio(e).message;
    final failure = switch (apiCodeOf(e)) {
      'NUMERO_NO_DISPONIBLE' => BookingFailure.numberUnavailable,
      'ANTICIPACION_INVALIDA' => BookingFailure.outsideWindow,
      'LIMITE_TOTAL' => BookingFailure.totalLimit,
      'LIMITE_ESPECIALIDAD' => BookingFailure.specialtyLimit,
      'CONSULTA_SUPERPUESTA' => BookingFailure.overlap,
      'PASE_NO_VALIDO' => BookingFailure.invalidReferral,
      'VALIDACION' => BookingFailure.validation,
      'NO_ENCONTRADO' => BookingFailure.notFound,
      'NO_AUTENTICADO' => BookingFailure.unauthenticated,
      'ACCESO_DENEGADO' => BookingFailure.forbidden,
      _ => BookingFailure.other,
    };
    return BookingException(failure, message);
  }
}
