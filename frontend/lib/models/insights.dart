class SuscripcionItem {
  final String descripcion;
  final double monto;
  final String categoria;

  const SuscripcionItem({
    required this.descripcion,
    required this.monto,
    required this.categoria,
  });

  factory SuscripcionItem.fromJson(Map<String, dynamic> j) => SuscripcionItem(
        descripcion: j['descripcion'] as String,
        monto: (j['monto'] as num).toDouble(),
        categoria: j['categoria'] as String,
      );
}

class Suscripciones {
  final double totalMensual;
  final List<SuscripcionItem> items;

  const Suscripciones({required this.totalMensual, required this.items});

  factory Suscripciones.fromJson(Map<String, dynamic> j) => Suscripciones(
        totalMensual: (j['total_mensual'] as num).toDouble(),
        items: (j['items'] as List)
            .map((e) => SuscripcionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Comparativo {
  final String mesActual;
  final String mesAnterior;
  final double gastosActual;
  final double gastosAnterior;
  final double delta;

  const Comparativo({
    required this.mesActual,
    required this.mesAnterior,
    required this.gastosActual,
    required this.gastosAnterior,
    required this.delta,
  });

  factory Comparativo.fromJson(Map<String, dynamic> j) => Comparativo(
        mesActual: j['mes_actual'] as String,
        mesAnterior: j['mes_anterior'] as String,
        gastosActual: (j['gastos_actual'] as num).toDouble(),
        gastosAnterior: (j['gastos_anterior'] as num).toDouble(),
        delta: (j['delta'] as num).toDouble(),
      );
}
