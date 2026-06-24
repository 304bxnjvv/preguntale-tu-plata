import 'package:flutter/material.dart';
import '../theme.dart';

/// Presencia abstracta — la "voz de tu plata". Orbe ámbar→índigo que respira/pulsa.
/// No es mascota: es una forma viva. `thinking` acelera el pulso.
class Orb extends StatefulWidget {
  final double size;
  final bool thinking;
  const Orb({super.key, this.size = 72, this.thinking = false});

  @override
  State<Orb> createState() => _OrbState();
}

class _OrbState extends State<Orb> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant Orb old) {
    super.didUpdateWidget(old);
    _c.duration = Duration(milliseconds: widget.thinking ? 900 : 2600);
    if (!_c.isAnimating) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = Curves.easeInOut.transform(_c.value);
        final scale = 0.94 + t * 0.10;
        final glow = 0.30 + t * 0.35;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [AppColors.accent, AppColors.primary],
              center: Alignment(-0.3, -0.4),
              radius: 0.95,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: glow),
                blurRadius: widget.size * 0.5,
                spreadRadius: widget.size * 0.06,
              ),
            ],
          ),
          transform: Matrix4.diagonal3Values(scale, scale, 1),
          transformAlignment: Alignment.center,
        );
      },
    );
  }
}
