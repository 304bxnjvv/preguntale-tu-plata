import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

const _base = 'http://localhost:8000/api/v1';

class ApiService {
  static Future<UploadResult> uploadCsv(
    Uint8List bytes,
    String filename,
    String banco,
  ) async {
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/upload?banco=$banco'),
    );
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();
    final json = jsonDecode(body);
    if (streamed.statusCode == 201) {
      return UploadResult(
        banco: json['banco'],
        count: json['transacciones_procesadas'],
      );
    }
    throw Exception(json['detail'] ?? 'Error al subir el archivo');
  }

  static Future<AskResult> ask(String question) async {
    final res = await http.post(
      Uri.parse('$_base/ask'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode({'question': question}),
    );
    if (res.statusCode == 200) {
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      return AskResult(
        answer: json['answer'],
        citations: (json['citations'] as List)
            .map((c) => Citation(
                  fecha: c['fecha'],
                  descripcion: c['descripcion'],
                  monto: (c['monto'] as num).toDouble(),
                ))
            .toList(),
      );
    }
    throw Exception('Error al procesar la pregunta');
  }
}

class UploadResult {
  final String banco;
  final int count;
  const UploadResult({required this.banco, required this.count});
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
