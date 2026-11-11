import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_routes.dart';
import '../models/doctor_attention.dart';
import '../models/doctor_attention_query.dart';
import 'doctor_attention_repository.dart';

class ApiDoctorAttentionRepository implements DoctorAttentionRepository {
  ApiDoctorAttentionRepository(this.dio);
  final Dio dio;
  @override
  Future<List<DoctorAttention>> list(DoctorAttentionQuery query) async {
    try {
      final data = (await dio.get<dynamic>(
        ApiRoutes.doctorAttentions,
        queryParameters: query.toQueryParameters(),
      )).data;
      if (data is! List) throw const ApiException();
      return data
          .map((item) => DoctorAttention.fromJson(item as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw _map(e);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  @override
  Future<DoctorAttention> get(int id) async {
    if (id <= 0) {
      throw const DoctorAttentionException(
        DoctorAttentionFailure.validation,
        attentionValidationMessage,
      );
    }
    try {
      final data = (await dio.get<dynamic>(ApiRoutes.doctorAttention(id))).data;
      return DoctorAttention.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _map(e);
    } on FormatException {
      throw const ApiException();
    } on TypeError {
      throw const ApiException();
    }
  }

  ApiException _map(DioException e) {
    final code = apiCodeOf(e);
    if (code == 'VALIDACION') {
      return const DoctorAttentionException(
        DoctorAttentionFailure.validation,
        attentionValidationMessage,
      );
    }
    if (code == 'ORDEN_INVALIDO' || code == 'SENTIDO_INVALIDO') {
      return const ApiException();
    }
    if (e.response?.statusCode == 403 || code == 'ACCESO_DENEGADO') {
      return const DoctorAttentionException(
        DoctorAttentionFailure.forbidden,
        attentionForbiddenMessage,
      );
    }
    if (e.response?.statusCode == 404 || code == 'NO_ENCONTRADO') {
      return const DoctorAttentionException(
        DoctorAttentionFailure.notFound,
        attentionNotFoundMessage,
      );
    }
    return ApiException.fromDio(e);
  }
}
