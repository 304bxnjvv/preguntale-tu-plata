class Cuota {
  final String descripcion;
  final double valorCuota;
  final int cuotasRestantes;

  const Cuota({
    required this.descripcion,
    required this.valorCuota,
    required this.cuotasRestantes,
  });

  factory Cuota.fromJson(Map<String, dynamic> j) => Cuota(
        descripcion: j['descripcion'] as String,
        valorCuota: (j['valor_cuota'] as num).toDouble(),
        cuotasRestantes: (j['cuotas_restantes'] as num).toInt(),
      );
}

class TarjetaEstado {
  final bool tieneDatos;
  final double totalAPagar;
  final double montoMinimo;
  final String? fechaVencimiento;
  final double cupoTotal;
  final double cupoUtilizado;
  final double comprometidoProximoMes;
  final List<Cuota> cuotas;

  const TarjetaEstado({
    required this.tieneDatos,
    required this.totalAPagar,
    required this.montoMinimo,
    this.fechaVencimiento,
    required this.cupoTotal,
    required this.cupoUtilizado,
    required this.comprometidoProximoMes,
    required this.cuotas,
  });

  factory TarjetaEstado.fromJson(Map<String, dynamic> j) => TarjetaEstado(
        tieneDatos: j['tiene_datos'] as bool,
        totalAPagar: (j['total_a_pagar'] as num).toDouble(),
        montoMinimo: (j['monto_minimo'] as num).toDouble(),
        fechaVencimiento: j['fecha_vencimiento'] as String?,
        cupoTotal: (j['cupo_total'] as num).toDouble(),
        cupoUtilizado: (j['cupo_utilizado'] as num).toDouble(),
        comprometidoProximoMes: (j['comprometido_proximo_mes'] as num).toDouble(),
        cuotas: (j['cuotas'] as List)
            .map((e) => Cuota.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
