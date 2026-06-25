class PresupuestoEstado {
  final String categoria;
  final double montoTope;
  final double gastado;
  final double pct;

  /// 'ok' | 'cerca' | 'excedido'
  final String estado;

  const PresupuestoEstado({
    required this.categoria,
    required this.montoTope,
    required this.gastado,
    required this.pct,
    required this.estado,
  });

  factory PresupuestoEstado.fromJson(Map<String, dynamic> j) => PresupuestoEstado(
        categoria: j['categoria'] as String,
        montoTope: (j['monto_tope'] as num).toDouble(),
        gastado: (j['gastado'] as num).toDouble(),
        pct: (j['pct'] as num).toDouble(),
        estado: j['estado'] as String,
      );
}
