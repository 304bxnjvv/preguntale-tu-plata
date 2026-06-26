/// Respuesta del endpoint GET /categorias
class CategoriasData {
  final List<String> base;
  final List<String> personalizadas;
  final List<String> todas;

  const CategoriasData({
    required this.base,
    required this.personalizadas,
    required this.todas,
  });

  factory CategoriasData.fromJson(Map<String, dynamic> j) => CategoriasData(
        base: List<String>.from(j['base'] as List),
        personalizadas: List<String>.from(j['personalizadas'] as List),
        todas: List<String>.from(j['todas'] as List),
      );
}
