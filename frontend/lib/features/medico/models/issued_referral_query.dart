import 'issued_referral.dart';

enum IssuedReferralOrder {
  expiry('vencimiento', 'Vencimiento'),
  issue('emision', 'Fecha de emisión');

  const IssuedReferralOrder(this.apiValue, this.label);

  final String apiValue;
  final String label;
}

enum IssuedReferralDirection {
  ascending('asc'),
  descending('desc');

  const IssuedReferralDirection(this.apiValue);

  final String apiValue;
}

/// Lo que se le pide a `GET /api/medico/pases`. Por defecto: sin filtro de
/// situación, por vencimiento y ascendente.
class IssuedReferralQuery {
  const IssuedReferralQuery({
    this.status,
    this.order = IssuedReferralOrder.expiry,
    this.direction = IssuedReferralDirection.ascending,
  });

  final ReferralStatus? status;
  final IssuedReferralOrder order;
  final IssuedReferralDirection direction;

  /// `situacion` solo si hay filtro; `orden` y `sentido` siempre.
  Map<String, String> toQueryParameters() => {
    if (status != null) 'situacion': status!.apiValue,
    'orden': order.apiValue,
    'sentido': direction.apiValue,
  };

  IssuedReferralQuery withStatus(ReferralStatus? value) =>
      IssuedReferralQuery(status: value, order: order, direction: direction);

  IssuedReferralQuery withOrder(
    IssuedReferralOrder value, {
    required IssuedReferralDirection direction,
  }) => IssuedReferralQuery(status: status, order: value, direction: direction);

  @override
  bool operator ==(Object other) =>
      other is IssuedReferralQuery &&
      other.status == status &&
      other.order == order &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(status, order, direction);
}
