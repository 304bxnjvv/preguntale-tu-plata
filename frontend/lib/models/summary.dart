class MonedaTotales {
  final double ingresos;
  final double gastos; // negativo
  const MonedaTotales({required this.ingresos, required this.gastos});

  factory MonedaTotales.fromJson(Map<String, dynamic> j) => MonedaTotales(
        ingresos: (j['ingresos'] as num).toDouble(),
        gastos: (j['gastos'] as num).toDouble(),
      );
}

class BancoTotal {
  final String banco;
  final double total; // negativo
  const BancoTotal({required this.banco, required this.total});

  factory BancoTotal.fromJson(Map<String, dynamic> j) => BancoTotal(
        banco: j['banco'] as String,
        total: (j['total'] as num).toDouble(),
      );
}

class CategoriaTotal {
  final String categoria;
  final double total; // negativo
  const CategoriaTotal({required this.categoria, required this.total});

  factory CategoriaTotal.fromJson(Map<String, dynamic> j) => CategoriaTotal(
        categoria: j['categoria'] as String,
        total: (j['total'] as num).toDouble(),
      );
}

class Summary {
  final Map<String, MonedaTotales> porMoneda;
  final List<CategoriaTotal> gastosPorCategoria;
  final List<BancoTotal> gastosPorBanco;

  const Summary({
    required this.porMoneda,
    required this.gastosPorCategoria,
    required this.gastosPorBanco,
  });

  factory Summary.fromJson(Map<String, dynamic> j) => Summary(
        porMoneda: (j['por_moneda'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, MonedaTotales.fromJson(v as Map<String, dynamic>)),
        ),
        gastosPorCategoria: (j['gastos_por_categoria'] as List)
            .map((e) => CategoriaTotal.fromJson(e as Map<String, dynamic>))
            .toList(),
        gastosPorBanco: (j['gastos_por_banco'] as List)
            .map((e) => BancoTotal.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
