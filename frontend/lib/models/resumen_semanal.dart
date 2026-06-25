class ResumenSemanal {
  final bool tieneDatos;
  final String periodo;
  final double gastoSemana;
  final String? topCategoria;
  final double topMonto;
  final double? deltaPct;
  final String texto;

  const ResumenSemanal({
    required this.tieneDatos,
    required this.periodo,
    required this.gastoSemana,
    this.topCategoria,
    required this.topMonto,
    this.deltaPct,
    required this.texto,
  });

  factory ResumenSemanal.fromJson(Map<String, dynamic> j) => ResumenSemanal(
        tieneDatos: j['tiene_datos'] as bool,
        periodo: j['periodo'] as String,
        gastoSemana: (j['gasto_semana'] as num).toDouble(),
        topCategoria: j['top_categoria'] as String?,
        topMonto: (j['top_monto'] as num).toDouble(),
        deltaPct: j['delta_pct'] == null ? null : (j['delta_pct'] as num).toDouble(),
        texto: j['texto'] as String,
      );
}
