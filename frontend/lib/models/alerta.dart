class Alerta {
  final String key;
  final String tipo;

  /// 'urgent' | 'warning' | 'info'
  final String severidad;
  final String titulo;
  final String detalle;
  final String fecha;

  const Alerta({
    required this.key,
    required this.tipo,
    required this.severidad,
    required this.titulo,
    required this.detalle,
    required this.fecha,
  });

  factory Alerta.fromJson(Map<String, dynamic> j) => Alerta(
        key: j['key'] as String,
        tipo: j['tipo'] as String,
        severidad: j['severidad'] as String,
        titulo: j['titulo'] as String,
        detalle: j['detalle'] as String,
        fecha: j['fecha'] as String,
      );
}
