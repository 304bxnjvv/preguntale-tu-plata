import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/data_providers.dart';
import '../services/api_service.dart';

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
      appBar: AppBar(title: const Text('Pregúntale a tu plata')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _msgs.length,
              itemBuilder: (_, i) {
                final m = _msgs[i];
                return Align(
                  alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: m.user ? const Color(0xFF1F6FEB) : const Color(0xFF161B22),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(m.text, style: const TextStyle(color: Color(0xFFE6EDF3))),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _input,
                onSubmitted: (_) => _enviar(),
                decoration: const InputDecoration(hintText: '¿Cuánto gasté este mes?'),
              )),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _cargando ? null : _enviar,
                icon: _cargando
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
