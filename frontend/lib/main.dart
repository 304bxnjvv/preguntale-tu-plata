import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: Config.supabaseUrl,
    // ignore: deprecated_member_use
    anonKey: Config.supabaseAnonKey,
  );
  runApp(const ProviderScope(child: PreguntaleApp()));
}

class PreguntaleApp extends ConsumerWidget {
  const PreguntaleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Pregúntale a tu plata',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        colorScheme: const ColorScheme.dark(
          surface: Color(0xFF161B22),
          primary: Color(0xFF00C896),
          onPrimary: Color(0xFF0D1117),
        ),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
