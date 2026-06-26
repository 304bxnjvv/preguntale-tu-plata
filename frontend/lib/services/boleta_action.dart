import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/data_providers.dart';

/// Captura una foto de boleta (cámara en móvil, galería en web) y navega a
/// la pantalla de confirmación. Si hay error, muestra un SnackBar.
/// Función pública para compartir entre DashboardScreen y AppDrawer.
Future<void> escanearBoleta(BuildContext context, WidgetRef ref) async {
  final picker = ImagePicker();
  // En web no existe la cámara nativa; caemos a galería.
  final source = kIsWeb ? ImageSource.gallery : ImageSource.camera;
  XFile? file;
  try {
    file = await picker.pickImage(source: source, imageQuality: 85);
  } catch (_) {
    // Si la cámara no está disponible (ej: emulador), intentar galería.
    try {
      file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo acceder a la cámara ni a la galería')),
        );
      }
      return;
    }
  }

  if (file == null) return; // usuario canceló

  final bytes = await file.readAsBytes();
  final ext = file.name.split('.').last.toLowerCase();
  final api = ref.read(apiProvider);

  try {
    final draft =
        await api.escanearBoleta(bytes, file.name.isNotEmpty ? file.name : 'boleta.$ext');
    if (context.mounted) {
      final guardado = await context.push<bool>('/boleta', extra: draft);
      if (guardado == true) _refrescarDatos(ref);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }
}

void _refrescarDatos(WidgetRef ref) {
  ref.invalidate(summaryProvider);
  ref.invalidate(transactionsProvider);
  ref.invalidate(suscripcionesProvider);
  ref.invalidate(comparativoProvider);
  ref.invalidate(finScoreProvider);
  ref.invalidate(tarjetaProvider);
  ref.invalidate(presupuestosProvider);
  ref.invalidate(metasProvider);
  ref.invalidate(alertasProvider);
  ref.invalidate(resumenSemanalProvider);
  ref.invalidate(forecastProvider);
}
