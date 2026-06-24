import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:http/http.dart' as http;
import 'package:preguntale_tu_plata/services/api_service.dart';

void main() {
  test('uploadFile pega a /transactions/upload con Bearer', () async {
    late http.BaseRequest captured;
    final mock = MockClient.streaming((req, body) async {
      captured = req;
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(
            {'banco': 'bci', 'transacciones_procesadas': 2, 'message': 'ok'}))),
        201,
      );
    });
    final api = ApiService(client: mock, token: () => 'T', baseUrl: 'http://x/api/v1');

    final r = await api.uploadFile(Uint8List.fromList([1, 2, 3]), 'cartola.pdf');

    expect(captured.url.path, contains('/transactions/upload'));
    expect(captured.headers['Authorization'], 'Bearer T');
    expect(r.count, 2);
  });
}
