import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/chat_message.dart';
import '../models/transaction.dart';
import '../models/summary.dart';
import '../models/insights.dart';
import '../models/finscore.dart';
import '../models/tarjeta.dart';
import '../models/presupuesto.dart';
import '../models/meta.dart';
import '../models/alerta.dart';
import '../models/resumen_semanal.dart';
import '../models/forecast.dart';

class Subscription {
  final String estado;
  final int diasRestantes;
  final String? trialEndsAt;
  final int precioClp;

  const Subscription({
    required this.estado,
    required this.diasRestantes,
    this.trialEndsAt,
    required this.precioClp,
  });

  factory Subscription.fromJson(Map<String, dynamic> j) => Subscription(
        estado: j['estado'] as String,
        diasRestantes: (j['dias_restantes'] as num).toInt(),
        trialEndsAt: j['trial_ends_at'] as String?,
        precioClp: (j['precio_clp'] as num).toInt(),
      );
}

class ApiService {
  final http.Client _client;
  final String? Function() _token;
  final String baseUrl;

  ApiService({
    http.Client? client,
    required String? Function() token,
    this.baseUrl = Config.backendBaseUrl,
  })  : _client = client ?? http.Client(),
        _token = token;

  Map<String, String> _headers([Map<String, String>? extra]) => {
        'Authorization': 'Bearer ${_token() ?? ''}',
        if (extra != null) ...extra,
      };

  Future<Summary> getSummary({int? dias, String? tipo}) async {
    final params = <String, String>{
      if (dias != null) 'dias': '$dias',
      if (tipo != null) 'tipo': tipo,
    };
    final uri = Uri.parse('$baseUrl/transactions/summary')
        .replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await _client.get(uri, headers: _headers());
    if (res.statusCode == 200) {
      return Summary.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('No se pudo cargar el resumen', res.statusCode);
  }

  Future<List<Transaction>> getTransactions({int? dias, String? tipo}) async {
    final params = <String, String>{
      if (dias != null) 'dias': '$dias',
      if (tipo != null) 'tipo': tipo,
    };
    final uri = Uri.parse('$baseUrl/transactions')
        .replace(queryParameters: params.isNotEmpty ? params : null);
    final res = await _client.get(uri, headers: _headers());
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      return list.map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException('No se pudieron cargar las transacciones', res.statusCode);
  }

  Future<List<ChatMessage>> getChatHistory() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/chat/history'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException('No se pudo cargar el historial', res.statusCode);
  }

  Future<AskResult> ask(String question) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/chat/ask'),
      headers: _headers({'Content-Type': 'application/json; charset=utf-8'}),
      body: jsonEncode({'question': question}),
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      return AskResult(
        answer: j['answer'] as String,
        citations: (j['citations'] as List)
            .map((c) => Citation(
                  fecha: c['fecha'] as String,
                  descripcion: c['descripcion'] as String,
                  monto: (c['monto'] as num).toDouble(),
                ))
            .toList(),
      );
    }
    throw ApiException('No se pudo procesar la pregunta', res.statusCode);
  }

  Future<Suscripciones> getSuscripciones() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/insights/suscripciones'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return Suscripciones.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('No se pudieron cargar las suscripciones', res.statusCode);
  }

  Future<FinScore> getFinScore() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/insights/finscore'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return FinScore.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('No se pudo cargar el FinScore', res.statusCode);
  }

  Future<TarjetaEstado> getTarjeta() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/insights/tarjeta'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return TarjetaEstado.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('No se pudo cargar la tarjeta', res.statusCode);
  }

  Future<Comparativo> getComparativo() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/insights/comparativo'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return Comparativo.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('No se pudo cargar el comparativo', res.statusCode);
  }

  Future<int> seedDemo() async {
    final res = await _client.post(
      Uri.parse('$baseUrl/demo/seed'),
      headers: _headers(),
    );
    if (res.statusCode == 201) {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      return j['inserted'] as int;
    }
    throw ApiException('No se pudo cargar el demo', res.statusCode);
  }

  Future<void> clearDemo() async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/demo/seed'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw ApiException('No se pudo limpiar el demo', res.statusCode);
    }
  }

  Future<Subscription> getSubscription() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/subscription'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return Subscription.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('No se pudo cargar la suscripción', res.statusCode);
  }

  /// Returns the checkout URL, or throws ApiException(503) when payment is not configured.
  Future<String> checkout() async {
    final res = await _client.post(
      Uri.parse('$baseUrl/subscription/checkout'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      return j['url'] as String;
    }
    throw ApiException(
      res.statusCode == 503
          ? 'pago no configurado'
          : 'No se pudo iniciar el pago',
      res.statusCode,
    );
  }

  Future<void> cancelSubscription() async {
    final res = await _client.post(
      Uri.parse('$baseUrl/subscription/cancel'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw ApiException('No se pudo cancelar la suscripción', res.statusCode);
    }
  }

  Future<void> deleteAccountData() async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/account/data'),
      headers: _headers(),
    );
    if (res.statusCode != 200) {
      throw ApiException('No se pudo eliminar los datos', res.statusCode);
    }
  }

  // ── Presupuestos ────────────────────────────────────────────────────────────

  Future<List<PresupuestoEstado>> getPresupuestos() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/presupuestos'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      final list = j['items'] as List;
      return list.map((e) => PresupuestoEstado.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException('No se pudieron cargar los presupuestos', res.statusCode);
  }

  Future<PresupuestoEstado> setTope(String categoria, num montoTope) async {
    final res = await _client.post(
      Uri.parse('$baseUrl/presupuestos'),
      headers: _headers({'Content-Type': 'application/json; charset=utf-8'}),
      body: jsonEncode({'categoria': categoria, 'monto_tope': montoTope}),
    );
    if (res.statusCode == 200) {
      return PresupuestoEstado.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('No se pudo fijar el tope', res.statusCode);
  }

  Future<bool> deleteTope(String categoria) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/presupuestos/$categoria'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(utf8.decode(res.bodyBytes))['ok'] as bool);
    }
    throw ApiException('No se pudo eliminar el tope', res.statusCode);
  }

  // ── Metas ───────────────────────────────────────────────────────────────────

  Future<List<Meta>> getMetas() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/metas'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      final list = j['items'] as List;
      return list.map((e) => Meta.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException('No se pudieron cargar las metas', res.statusCode);
  }

  Future<Meta> crearMeta(String nombre, num montoObjetivo, {String? fechaObjetivo}) async {
    final body = <String, dynamic>{
      'nombre': nombre,
      'monto_objetivo': montoObjetivo,
      if (fechaObjetivo != null) 'fecha_objetivo': fechaObjetivo,
    };
    final res = await _client.post(
      Uri.parse('$baseUrl/metas'),
      headers: _headers({'Content-Type': 'application/json; charset=utf-8'}),
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) {
      return Meta.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('No se pudo crear la meta', res.statusCode);
  }

  Future<Meta> actualizarMeta(
    String id, {
    String? nombre,
    num? montoObjetivo,
    num? montoActual,
    String? fechaObjetivo,
  }) async {
    final body = <String, dynamic>{
      if (nombre != null) 'nombre': nombre,
      if (montoObjetivo != null) 'monto_objetivo': montoObjetivo,
      if (montoActual != null) 'monto_actual': montoActual,
      if (fechaObjetivo != null) 'fecha_objetivo': fechaObjetivo,
    };
    final res = await _client.patch(
      Uri.parse('$baseUrl/metas/$id'),
      headers: _headers({'Content-Type': 'application/json; charset=utf-8'}),
      body: jsonEncode(body),
    );
    if (res.statusCode == 200) {
      return Meta.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('No se pudo actualizar la meta', res.statusCode);
  }

  Future<bool> eliminarMeta(String id) async {
    final res = await _client.delete(
      Uri.parse('$baseUrl/metas/$id'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(utf8.decode(res.bodyBytes))['ok'] as bool);
    }
    throw ApiException('No se pudo eliminar la meta', res.statusCode);
  }

  // ── Alertas ─────────────────────────────────────────────────────────────────

  Future<ResumenSemanal> getResumenSemanal() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/insights/resumen-semanal'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return ResumenSemanal.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('No se pudo cargar el resumen semanal', res.statusCode);
  }

  Future<Forecast> getForecast() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/insights/forecast'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return Forecast.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('No se pudo cargar la proyección', res.statusCode);
  }

  Future<List<Alerta>> getAlertas() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/insights/alertas'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final j = jsonDecode(utf8.decode(res.bodyBytes));
      final list = j['items'] as List;
      return list.map((e) => Alerta.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException('No se pudieron cargar las alertas', res.statusCode);
  }

  Future<int> editarCategoria(String id, String categoria) async {
    final res = await _client.patch(
      Uri.parse('$baseUrl/transactions/$id'),
      headers: _headers({'Content-Type': 'application/json; charset=utf-8'}),
      body: jsonEncode({'categoria': categoria}),
    );
    if (res.statusCode == 200) {
      return (jsonDecode(utf8.decode(res.bodyBytes))['actualizadas'] as num).toInt();
    }
    throw ApiException('No se pudo cambiar la categoría', res.statusCode);
  }

  Future<UploadResult> uploadFile(Uint8List bytes, String filename) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/transactions/upload'),
    );
    req.headers.addAll(_headers());
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await _client.send(req);
    final body = await streamed.stream.bytesToString();
    final j = jsonDecode(body);
    if (streamed.statusCode == 201) {
      return UploadResult(banco: j['banco'] as String, count: j['transacciones_procesadas'] as int);
    }
    throw ApiException(j['detail']?.toString() ?? 'Error al subir el archivo', streamed.statusCode);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  ApiException(this.message, this.statusCode);
  @override
  String toString() => message;
}

class AskResult {
  final String answer;
  final List<Citation> citations;
  const AskResult({required this.answer, required this.citations});
}

class Citation {
  final String fecha;
  final String descripcion;
  final double monto;
  const Citation({required this.fecha, required this.descripcion, required this.monto});
}

class UploadResult {
  final String banco;
  final int count;
  const UploadResult({required this.banco, required this.count});
}
