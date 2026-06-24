class Transaction {
  final String id;
  final String fecha;
  final String descripcion;
  final double monto;
  final String moneda;
  final String? tarjeta;
  final String tipo;
  final String? categoria;
  final String banco;
  final String fuente;

  const Transaction({
    required this.id,
    required this.fecha,
    required this.descripcion,
    required this.monto,
    required this.moneda,
    required this.tarjeta,
    required this.tipo,
    required this.categoria,
    required this.banco,
    required this.fuente,
  });

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: j['id'] as String,
        fecha: j['fecha'] as String,
        descripcion: j['descripcion'] as String,
        monto: (j['monto'] as num).toDouble(),
        moneda: j['moneda'] as String,
        tarjeta: j['tarjeta'] as String?,
        tipo: j['tipo'] as String,
        categoria: j['categoria'] as String?,
        banco: j['banco'] as String,
        fuente: j['fuente'] as String,
      );
}
