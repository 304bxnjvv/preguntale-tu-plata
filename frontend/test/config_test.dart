import 'package:flutter_test/flutter_test.dart';
import 'package:preguntale_tu_plata/config.dart';

void main() {
  test('config tiene URL de supabase y backend válidos', () {
    expect(Config.supabaseUrl, startsWith('https://'));
    expect(Config.supabaseAnonKey, isNotEmpty);
    expect(Config.backendBaseUrl, contains('/api/v1'));
  });
}
