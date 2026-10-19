enum SubmitStatus { idle, loading, done, error }

/// Estado de un formulario que se envía una vez (alta de algo). Lo usan los
/// controllers de las altas del administrador.
class SubmitState {
  const SubmitState({this.status = SubmitStatus.idle, this.errorMessage});

  final SubmitStatus status;

  /// Solo con [SubmitStatus.error]: texto para mostrar al usuario.
  final String? errorMessage;

  bool get isLoading => status == SubmitStatus.loading;
}
