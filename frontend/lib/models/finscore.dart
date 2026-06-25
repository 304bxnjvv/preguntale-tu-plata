class FinFactor {
  final String texto;
  final String signo; // '+' | '-'

  const FinFactor({required this.texto, required this.signo});

  factory FinFactor.fromJson(Map<String, dynamic> j) => FinFactor(
        texto: j['texto'] as String,
        signo: j['signo'] as String,
      );
}

class FinScore {
  final int score;
  final String nivel; // 'vas bien' | 'ojo' | 'alerta' | 'sin datos'
  final String resumen;
  final List<FinFactor> factores;
  final double tasaAhorro;

  const FinScore({
    required this.score,
    required this.nivel,
    required this.resumen,
    required this.factores,
    required this.tasaAhorro,
  });

  factory FinScore.fromJson(Map<String, dynamic> j) => FinScore(
        score: (j['score'] as num).toInt(),
        nivel: j['nivel'] as String,
        resumen: j['resumen'] as String,
        factores: (j['factores'] as List)
            .map((f) => FinFactor.fromJson(f as Map<String, dynamic>))
            .toList(),
        tasaAhorro: (j['tasa_ahorro'] as num).toDouble(),
      );
}
