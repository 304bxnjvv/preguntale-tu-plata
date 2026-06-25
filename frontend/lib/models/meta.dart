class Meta {
  final String id;
  final String nombre;
  final double montoObjetivo;
  final double montoActual;
  final String? fechaObjetivo;

  /// Fracción 0–1 (clamp).
  final double progreso;

  /// Null cuando no hay fecha objetivo.
  final double? aporteMensualNecesario;

  const Meta({
    required this.id,
    required this.nombre,
    required this.montoObjetivo,
    required this.montoActual,
    this.fechaObjetivo,
    required this.progreso,
    this.aporteMensualNecesario,
  });

  factory Meta.fromJson(Map<String, dynamic> j) => Meta(
        id: j['id'] as String,
        nombre: j['nombre'] as String,
        montoObjetivo: (j['monto_objetivo'] as num).toDouble(),
        montoActual: (j['monto_actual'] as num).toDouble(),
        fechaObjetivo: j['fecha_objetivo'] as String?,
        progreso: (j['progreso'] as num).toDouble(),
        aporteMensualNecesario: j['aporte_mensual_necesario'] == null
            ? null
            : (j['aporte_mensual_necesario'] as num).toDouble(),
      );
}
