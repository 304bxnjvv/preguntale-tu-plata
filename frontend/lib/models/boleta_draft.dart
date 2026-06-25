class BoletaDraft {
  final String comercio;
  final double monto;
  final String fecha;
  final String? categoria;

  const BoletaDraft({
    required this.comercio,
    required this.monto,
    required this.fecha,
    this.categoria,
  });

  factory BoletaDraft.fromJson(Map<String, dynamic> j) => BoletaDraft(
        comercio: j['comercio'] as String,
        monto: (j['monto'] as num).toDouble(),
        fecha: j['fecha'] as String,
        categoria: j['categoria'] as String?,
      );
}
