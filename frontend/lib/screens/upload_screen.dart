import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/data_providers.dart';
import '../services/api_service.dart';

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});
  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  bool _cargando = false;
  String? _msg;

  Future<void> _subir() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'csv', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res == null || res.files.single.bytes == null) return;
    setState(() {
      _cargando = true;
      _msg = null;
    });
    try {
      final r = await ref.read(apiProvider).uploadFile(
            res.files.single.bytes!, res.files.single.name);
      ref.invalidate(summaryProvider);
      ref.invalidate(transactionsProvider);
      setState(() => _msg = '${r.count} transacciones cargadas');
    } on ApiException catch (e) {
      setState(() => _msg = e.statusCode == 429
          ? 'Llegaste al límite de subidas del mes'
          : e.message);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Subir cartola o boleta')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Sube tu cartola (PDF/CSV) o una foto de boleta. La leemos con IA.',
                style: TextStyle(color: Color(0xFF8B949E))),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _cargando ? null : _subir,
              icon: const Icon(Icons.upload_file),
              label: Text(_cargando ? 'Procesando...' : 'Elegir archivo'),
            ),
            if (_msg != null) ...[
              const SizedBox(height: 16),
              Text(_msg!, textAlign: TextAlign.center),
            ],
          ],
        ),
      ),
    );
  }
}
