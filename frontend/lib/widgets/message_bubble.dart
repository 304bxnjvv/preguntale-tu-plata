import 'package:flutter/material.dart';
import '../screens/home_screen.dart';
import '../services/api.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            _Avatar(isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? const Color(0xFF1F6FEB)
                        : const Color(0xFF161B22),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                      bottomRight: Radius.circular(message.isUser ? 4 : 16),
                    ),
                    border: message.isUser
                        ? null
                        : Border.all(color: const Color(0xFF30363D)),
                  ),
                  child: Text(
                    message.text,
                    style: const TextStyle(
                      color: Color(0xFFE6EDF3),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                if (!message.isUser && message.citations.isNotEmpty)
                  _CitationsRow(citations: message.citations),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            _Avatar(isUser: true),
          ],
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final bool isUser;
  const _Avatar({required this.isUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFF1F6FEB) : const Color(0xFF00C896),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isUser ? Icons.person : Icons.attach_money,
        size: 16,
        color: isUser ? Colors.white : const Color(0xFF0D1117),
      ),
    );
  }
}

class _CitationsRow extends StatefulWidget {
  final List<Citation> citations;
  const _CitationsRow({required this.citations});

  @override
  State<_CitationsRow> createState() => _CitationsRowState();
}

class _CitationsRowState extends State<_CitationsRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final unique = widget.citations
        .fold<List<Citation>>([], (acc, c) {
          if (!acc.any((e) => e.fecha == c.fecha && e.descripcion == c.descripcion)) {
            acc.add(c);
          }
          return acc;
        });

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long, size: 12, color: Color(0xFF8B949E)),
                const SizedBox(width: 4),
                Text(
                  '${unique.length} transacciones fuente',
                  style: const TextStyle(color: Color(0xFF8B949E), fontSize: 11),
                ),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 14,
                  color: const Color(0xFF8B949E),
                ),
              ],
            ),
          ),
          if (_expanded)
            ...unique.map((c) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF30363D)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          c.fecha,
                          style: const TextStyle(
                              color: Color(0xFF8B949E), fontSize: 11),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            c.descripcion,
                            style: const TextStyle(
                                color: Color(0xFFE6EDF3), fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '\$${c.monto.abs().toStringAsFixed(0)} CLP',
                          style: TextStyle(
                            color: c.monto < 0
                                ? const Color(0xFFF85149)
                                : const Color(0xFF00C896),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFF00C896),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.attach_money,
                size: 16, color: Color(0xFF0D1117)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF30363D)),
            ),
            child: const SizedBox(
              width: 40,
              height: 10,
              child: _DotsAnimation(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotsAnimation extends StatefulWidget {
  const _DotsAnimation();

  @override
  State<_DotsAnimation> createState() => _DotsAnimationState();
}

class _DotsAnimationState extends State<_DotsAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (i) {
            final offset = (i / 3);
            final v = (_ctrl.value - offset).abs();
            final opacity = v < 0.33 ? 1.0 : 0.3;
            return Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Color.fromRGBO(0, 200, 150, opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
