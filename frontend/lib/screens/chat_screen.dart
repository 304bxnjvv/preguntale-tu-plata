import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../providers/data_providers.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/orb.dart';

class _Msg {
  final String text;
  final bool user;
  _Msg(this.text, this.user);
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});
  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _msgs = <_Msg>[];
  bool _cargando = false;
  bool _historyLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  Future<void> _loadHistory() async {
    try {
      final history = await ref.read(chatHistoryProvider.future);
      if (mounted) {
        setState(() {
          _msgs.addAll(history.map((m) => _Msg(m.content, m.role == 'user')));
          _historyLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _historyLoaded = true);
    }
  }

  Future<void> _enviar() async {
    final q = _input.text.trim();
    if (q.isEmpty || _cargando) return;
    setState(() {
      _msgs.add(_Msg(q, true));
      _cargando = true;
    });
    _input.clear();
    try {
      final r = await ref.read(apiProvider).ask(q);
      setState(() => _msgs.add(_Msg(r.answer, false)));
      // Refresh dashboard data — the backend may have logged an expense.
      ref.invalidate(summaryProvider);
      ref.invalidate(transactionsProvider);
      ref.invalidate(suscripcionesProvider);
    } on ApiException catch (e) {
      setState(() => _msgs.add(_Msg(e.message, false)));
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 16,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Orb(size: 28),
            const SizedBox(width: 10),
            Text('tu plata', style: AppText.body(17, weight: FontWeight.w600)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: !_historyLoaded
                ? const Center(child: Orb(size: 48, thinking: true))
                : _msgs.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: _msgs.length + (_cargando ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (_cargando && i == _msgs.length) {
                            return _ThinkingBubble();
                          }
                          final m = _msgs[i];
                          return m.user ? _UserBubble(m.text) : _AiBubble(m.text);
                        },
                      ),
          ),
          _InputBar(
            controller: _input,
            cargando: _cargando,
            onEnviar: _enviar,
          ),
        ],
      ),
    );
  }
}

// ── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Orb(size: 80),
            const SizedBox(height: 24),
            Text(
              'pregúntame lo que quieras sobre tu plata.',
              style: AppText.body(18, weight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'tipo: "¿en qué se me fue la plata este mes?"',
              style: AppText.body(14, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'o anota un gasto al toque: "gasté 5 lucas en almuerzo"',
              style: AppText.body(14, color: AppColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Burbujas ─────────────────────────────────────────────────────────────────

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, left: 56),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Text(text, style: AppText.body(16, color: AppColors.onPrimary)),
      ),
    );
  }
}

class _AiBubble extends StatelessWidget {
  final String text;
  const _AiBubble(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 56),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8, bottom: 2),
              child: Orb(size: 28),
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.glass,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(4),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(text, style: AppText.body(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 56),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8, bottom: 2),
              child: Orb(size: 28, thinking: true),
            ),
            Text(
              'pensando...',
              style: AppText.body(14, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Input bar ────────────────────────────────────────────────────────────────

class _InputBar extends StatefulWidget {
  final TextEditingController controller;
  final bool cargando;
  final VoidCallback onEnviar;

  const _InputBar({
    required this.controller,
    required this.cargando,
    required this.onEnviar,
  });

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  final SpeechToText _speech = SpeechToText();

  /// null = not yet probed; false = unavailable (hide button); true = available.
  bool? _speechAvailable;
  bool _escuchando = false;

  @override
  void initState() {
    super.initState();
    _probeSpeech();
  }

  Future<void> _probeSpeech() async {
    try {
      final ok = await _speech.initialize();
      if (mounted) setState(() => _speechAvailable = ok);
    } catch (_) {
      // Web or restricted platform — hide the mic silently.
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  Future<void> _toggleMic() async {
    if (_escuchando) {
      await _speech.stop();
      if (mounted) setState(() => _escuchando = false);
      return;
    }
    try {
      setState(() => _escuchando = true);
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult && result.recognizedWords.isNotEmpty) {
            widget.controller.text = result.recognizedWords;
            // Place cursor at end.
            widget.controller.selection = TextSelection.fromPosition(
              TextPosition(offset: widget.controller.text.length),
            );
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          localeId: 'es_CL',
        ),
      );
    } catch (_) {
      // If listening fails for any reason, just reset.
      if (mounted) setState(() => _escuchando = false);
    }

    // When the speech engine finishes (naturally or via timeout), reset flag.
    _speech.statusListener = (status) {
      if (status == 'done' || status == 'notListening') {
        if (mounted) setState(() => _escuchando = false);
      }
    };
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final showMic = _speechAvailable == true;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottom),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: widget.controller,
              onSubmitted: (_) => widget.onEnviar(),
              style: AppText.body(16),
              decoration: InputDecoration(
                hintText: '¿cuánto gasté este mes?',
                hintStyle: AppText.body(15, color: AppColors.textMuted),
              ),
            ),
          ),
          // Mic button — only shown when speech_to_text initialized OK.
          if (showMic) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 44,
              height: 44,
              child: Material(
                color: _escuchando
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _toggleMic,
                  child: Center(
                    child: Icon(
                      _escuchando
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      color: _escuchando
                          ? AppColors.onPrimary
                          : AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: widget.cargando
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: widget.cargando ? null : widget.onEnviar,
                child: Center(
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: AppColors.onPrimary,
                    size: 22,
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
