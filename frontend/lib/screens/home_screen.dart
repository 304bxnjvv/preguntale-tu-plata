import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api.dart';
import '../widgets/message_bubble.dart';
import '../widgets/upload_card.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<Citation> citations;
  ChatMessage({required this.text, required this.isUser, this.citations = const []});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  String _banco = 'bci';
  bool _uploading = false;
  bool _asking = false;
  UploadResult? _uploadResult;

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );
    if (result == null || result.files.single.bytes == null) return;

    setState(() => _uploading = true);
    try {
      final file = result.files.single;
      final upload = await ApiService.uploadCsv(
        file.bytes!,
        file.name,
        _banco,
      );
      setState(() {
        _uploadResult = upload;
        _messages.add(ChatMessage(
          text: '✅ ${upload.count} transacciones de ${upload.banco.toUpperCase()} cargadas. '
              'Ahora puedes preguntarme sobre tus gastos.',
          isUser: false,
        ));
      });
      _scrollToBottom();
    } catch (e) {
      _showError(e.toString());
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _sendMessage() async {
    final question = _inputController.text.trim();
    if (question.isEmpty || _asking) return;

    setState(() {
      _messages.add(ChatMessage(text: question, isUser: true));
      _asking = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      final result = await ApiService.ask(question);
      setState(() {
        _messages.add(ChatMessage(
          text: result.answer,
          isUser: false,
          citations: result.citations,
        ));
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add(ChatMessage(
          text: 'Ocurrió un error al procesar tu pregunta. Intenta de nuevo.',
          isUser: false,
        ));
      });
    } finally {
      setState(() => _asking = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFDA3633),
      ),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF00C896),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.attach_money, color: Color(0xFF0D1117), size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'Pregúntale a tu plata',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 18,
                color: Color(0xFFE6EDF3),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF30363D)),
        ),
      ),
      body: Column(
        children: [
          UploadCard(
            banco: _banco,
            uploading: _uploading,
            uploadResult: _uploadResult,
            onBancoChanged: (v) => setState(() => _banco = v),
            onUpload: _pickAndUpload,
          ),
          const Divider(height: 1, color: Color(0xFF30363D)),
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    itemCount: _messages.length + (_asking ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (_asking && i == _messages.length) {
                        return const TypingIndicator();
                      }
                      return MessageBubble(message: _messages[i]);
                    },
                  ),
          ),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline,
              size: 48, color: const Color(0xFF30363D)),
          const SizedBox(height: 16),
          Text(
            _uploadResult == null
                ? 'Sube tu estado de cuenta para comenzar'
                : '¿Qué quieres saber sobre tus gastos?',
            style: const TextStyle(color: Color(0xFF8B949E), fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1117),
        border: Border(top: BorderSide(color: Color(0xFF30363D))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              enabled: _uploadResult != null && !_asking,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: _uploadResult == null
                    ? 'Primero sube un estado de cuenta...'
                    : '¿Cuánto gasté en supermercado este mes?',
              ),
              style: const TextStyle(color: Color(0xFFE6EDF3)),
            ),
          ),
          const SizedBox(width: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            child: IconButton(
              onPressed: _uploadResult != null && !_asking ? _sendMessage : null,
              icon: _asking
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00C896),
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF00C896),
                foregroundColor: const Color(0xFF0D1117),
                disabledBackgroundColor: const Color(0xFF30363D),
                padding: const EdgeInsets.all(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
