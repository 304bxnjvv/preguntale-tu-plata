import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/transaction.dart';
import '../models/summary.dart';

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

  Future<Summary> getSummary() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/transactions/summary'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      return Summary.fromJson(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    throw ApiException('No se pudo cargar el resumen', res.statusCode);
  }

  Future<List<Transaction>> getTransactions() async {
    final res = await _client.get(
      Uri.parse('$baseUrl/transactions'),
      headers: _headers(),
    );
    if (res.statusCode == 200) {
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      return list.map((e) => Transaction.fromJson(e as Map<String, dynamic>)).toList();
    }
    throw ApiException('No se pudieron cargar las transacciones', res.statusCode);
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

  Future<UploadResult> uploadCsv(Uint8List bytes, String filename, String banco) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/transactions/upload-csv?banco=$banco'),
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
