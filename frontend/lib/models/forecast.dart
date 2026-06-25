class CategoriaRiesgo {
  final String categoria;
  final double tope;
  final double proyectado;
  final double pct;

  const CategoriaRiesgo({
    required this.categoria,
    required this.tope,
    required this.proyectado,
    required this.pct,
  });

  factory CategoriaRiesgo.fromJson(Map<String, dynamic> j) => CategoriaRiesgo(
        categoria: j['categoria'] as String,
        tope: (j['tope'] as num).toDouble(),
        proyectado: (j['proyectado'] as num).toDouble(),
        pct: (j['pct'] as num).toDouble(),
      );
}

class Forecast {
  final bool tieneDatos;
  final int diasRestantes;
  final int diaDelMes;
  final double gastoActual;
  final double gastoProyectado;
  final double ingresosMes;
  final double? netoProyectado;
  final List<CategoriaRiesgo> categoriasEnRiesgo;
  final String confianza;
  final String caveat;

  const Forecast({
    required this.tieneDatos,
    required this.diasRestantes,
    required this.diaDelMes,
    required this.gastoActual,
    required this.gastoProyectado,
    required this.ingresosMes,
    this.netoProyectado,
    required this.categoriasEnRiesgo,
    required this.confianza,
    required this.caveat,
  });

  factory Forecast.fromJson(Map<String, dynamic> j) => Forecast(
        tieneDatos: j['tiene_datos'] as bool,
        diasRestantes: (j['dias_restantes'] as num).toInt(),
        diaDelMes: (j['dia_del_mes'] as num).toInt(),
        gastoActual: (j['gasto_actual'] as num).toDouble(),
        gastoProyectado: (j['gasto_proyectado'] as num).toDouble(),
        ingresosMes: (j['ingresos_mes'] as num).toDouble(),
        netoProyectado:
            j['neto_proyectado'] == null ? null : (j['neto_proyectado'] as num).toDouble(),
        categoriasEnRiesgo: (j['categorias_en_riesgo'] as List)
            .map((e) => CategoriaRiesgo.fromJson(e as Map<String, dynamic>))
            .toList(),
        confianza: j['confianza'] as String,
        caveat: (j['caveat'] as String?) ?? '',
      );
}
