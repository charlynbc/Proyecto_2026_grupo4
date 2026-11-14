/// Qué página de avisos se pide (contrato: `page` desde 0, `size` de 1 a 100).
/// El orden es fijo del lado del servidor: `creadaEn` descendente.
class NotificationQuery {
  const NotificationQuery({this.page = 0, this.size = 20});

  final int page;
  final int size;

  Map<String, dynamic> toQueryParameters() => {'page': page, 'size': size};

  @override
  bool operator ==(Object other) =>
      other is NotificationQuery && other.page == page && other.size == size;

  @override
  int get hashCode => Object.hash(page, size);
}
