class Professional {
  const Professional({required this.id, required this.name});

  final int id;
  final String name;

  factory Professional.fromJson(Map<String, dynamic> json) =>
      Professional(id: json['id'] as int, name: json['nombre'] as String);
}
