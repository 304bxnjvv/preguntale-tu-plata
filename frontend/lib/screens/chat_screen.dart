import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  Future<void> _enviar() async {
    final q = _input.text.trim();
    if (q.isEmpty || _cargando) return;
    setState(() { _msgs.add(_Msg(q, true)); _cargando = true; });
    _input.clear();
    try {
      final r = await ref.read(apiProvider).ask(q);
      setState(() => _msgs.add(_Msg(r.answer, false)));
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
            child: _msgs.isEmpty
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
          _InputBar(controller: _input, cargando: _cargando, onEnviar: _enviar),
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

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool cargando;
  final VoidCallback onEnviar;

  const _InputBar({
    required this.controller,
    required this.cargando,
    required this.onEnviar,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
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
              controller: controller,
              onSubmitted: (_) => onEnviar(),
              style: AppText.body(16),
              decoration: InputDecoration(
                hintText: '¿cuánto gasté este mes?',
                hintStyle: AppText.body(15, color: AppColors.textMuted),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: cargando ? AppColors.primary.withValues(alpha: 0.4) : AppColors.primary,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: cargando ? null : onEnviar,
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
