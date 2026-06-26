import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme.dart';

class LegalScreen extends StatefulWidget {
  final String doc; // 'privacidad' | 'terminos'

  const LegalScreen({super.key, required this.doc});

  @override
  State<LegalScreen> createState() => _LegalScreenState();
}

class _LegalScreenState extends State<LegalScreen> {
  String? _contenido;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final asset = widget.doc == 'privacidad'
        ? 'assets/legal/politica-privacidad.md'
        : 'assets/legal/terminos-y-condiciones.md';
    try {
      final texto = await rootBundle.loadString(asset);
      if (mounted) setState(() => _contenido = texto);
    } catch (e) {
      if (mounted) setState(() => _error = 'No se pudo cargar el documento.');
    }
  }

  String get _titulo => widget.doc == 'privacidad'
      ? 'Política de privacidad'
      : 'Términos y condiciones';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textMuted),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_titulo, style: AppText.body(17, weight: FontWeight.w600)),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Amber banner
          Container(
            color: AppColors.accent.withValues(alpha: 0.15),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Borrador — pendiente de revisión legal',
                    style: AppText.body(13, color: AppColors.accent),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(
                    child: Text(_error!, style: AppText.body(14, color: AppColors.textMuted)),
                  )
                : _contenido == null
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      )
                    : Markdown(
                        data: _contenido!,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        styleSheet: MarkdownStyleSheet(
                          p: AppText.body(14, color: AppColors.text),
                          h1: AppText.display(22, weight: FontWeight.w700),
                          h2: AppText.display(18, weight: FontWeight.w600),
                          h3: AppText.body(16, weight: FontWeight.w600),
                          blockquote: AppText.body(13, color: AppColors.accent),
                          blockquoteDecoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          code: AppText.body(13, color: AppColors.textMuted),
                          codeblockDecoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          horizontalRuleDecoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.border),
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
