import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/data_providers.dart';
import '../theme.dart';
import '../widgets/orb.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _step = 0;
  final _guessController = TextEditingController();
  double? _guess;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _pageController.dispose();
    _guessController.dispose();
    super.dispose();
  }

  Future<void> _nextStep(int next) async {
    setState(() => _step = next);
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _seedDemo() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(apiProvider).seedDemo();
      ref.invalidate(summaryProvider);
      ref.invalidate(transactionsProvider);
      // wait for summary to load so reveal step can read it
      await ref.read(summaryProvider.future);
      if (mounted) await _nextStep(3);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'no pudimos cargar el ejemplo. intenta de nuevo.';
        });
      }
      return;
    }
    if (mounted) setState(() => _loading = false);
  }

  void _skip() => context.go('/dashboard');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _StepBienvenida(onNext: () => _nextStep(1), onSkip: _skip),
                _StepGuess(
                  controller: _guessController,
                  onNext: () {
                    final raw = _guessController.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')
                        .replaceAll('\$', '')
                        .trim();
                    _guess = double.tryParse(raw);
                    _nextStep(2);
                  },
                  onSkip: _skip,
                ),
                _StepElegir(
                  loading: _loading,
                  error: _error,
                  onSubir: () => context.push('/upload'),
                  onDemo: _seedDemo,
                  onSkip: _skip,
                ),
                _StepReveal(
                  guess: _guess,
                  onChat: () => context.go('/chat'),
                  onDashboard: () => context.go('/dashboard'),
                ),
              ],
            ),
            // Step indicators
            Positioned(
              top: 16,
              left: 0,
              right: 0,
              child: _StepDots(current: _step, total: 4),
            ),
            // Skip button (not on reveal)
            if (_step < 3)
              Positioned(
                top: 8,
                right: 16,
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'saltar',
                    style: AppText.body(14, color: AppColors.textMuted),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Step dots ─────────────────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  final int current;
  final int total;
  const _StepDots({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.border,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── Step 1 — Bienvenida + privacidad ─────────────────────────────────────────

class _StepBienvenida extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const _StepBienvenida({required this.onNext, required this.onSkip});

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Center(child: Orb(size: 80)),
          const SizedBox(height: 28),
          Text(
            'pregúntale\na tu plata',
            style: AppText.display(34, weight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          // Privacy glass card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.glass,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline, color: AppColors.accent, size: 18),
                    const SizedBox(width: 8),
                    Text('tu privacidad', style: AppText.label(AppColors.accent)),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'no le pedimos permiso a tu banco. solo los archivos que tú subes. tus datos se borran a 1 año o cuando tú quieras.',
                  style: AppText.body(15, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onNext,
            child: Text(
              'empezar',
              style: AppText.body(16, weight: FontWeight.w600, color: AppColors.onPrimary),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Step 2 — Pregunta estimativa ─────────────────────────────────────────────

class _StepGuess extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  const _StepGuess({
    required this.controller,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            '¿cuánto crees que\ngastas al mes\nen delivery?',
            style: AppText.display(30, weight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'delivery, Uber Eats, PedidosYa, lo que sea',
            style: AppText.body(14, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofocus: true,
            style: AppText.amount(28, color: AppColors.text),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              prefixText: '\$',
              prefixStyle: AppText.amount(28, color: AppColors.textMuted),
              hintText: '50.000',
              hintStyle: AppText.amount(28, color: AppColors.border),
            ),
            onSubmitted: (_) => onNext(),
          ),
          const Spacer(),
          FilledButton(
            onPressed: onNext,
            child: Text(
              'continuar',
              style: AppText.body(16, weight: FontWeight.w600, color: AppColors.onPrimary),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onSkip,
            child: Text(
              'no sé / saltar',
              style: AppText.body(14, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Step 3 — Elegir ───────────────────────────────────────────────────────────

class _StepElegir extends StatelessWidget {
  final bool loading;
  final String? error;
  final VoidCallback onSubir;
  final VoidCallback onDemo;
  final VoidCallback onSkip;

  const _StepElegir({
    required this.loading,
    required this.error,
    required this.onSubir,
    required this.onDemo,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return _StepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text(
            '¿cómo quieres\nempezar?',
            style: AppText.display(30, weight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Primary: subir cartola
          FilledButton.icon(
            onPressed: loading ? null : onSubir,
            icon: const Icon(Icons.upload_file_outlined, size: 20),
            label: Text(
              'subir mi cartola',
              style: AppText.body(16, weight: FontWeight.w600, color: AppColors.onPrimary),
            ),
          ),
          const SizedBox(height: 12),
          // Secondary: probar con demo
          OutlinedButton.icon(
            onPressed: loading ? null : onDemo,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  )
                : const Icon(Icons.play_circle_outline, size: 20),
            label: Text(
              loading ? 'cargando ejemplo...' : 'probar con un ejemplo',
              style: AppText.body(16, weight: FontWeight.w600),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            Text(
              error!,
              style: AppText.body(13, color: AppColors.negative),
              textAlign: TextAlign.center,
            ),
          ],
          const Spacer(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Step 4 — Reveal ───────────────────────────────────────────────────────────

class _StepReveal extends ConsumerWidget {
  final double? guess;
  final VoidCallback onChat;
  final VoidCallback onDashboard;

  const _StepReveal({
    required this.guess,
    required this.onChat,
    required this.onDashboard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryProvider);

    return _StepShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Center(child: Orb(size: 64)),
          const SizedBox(height: 24),
          summary.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (_, __) => Text(
              'tus datos están listos',
              style: AppText.display(26, weight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            data: (s) {
              // Find delivery/food category (case insensitive)
              final deliveryCat = s.gastosPorCategoria
                  .where((c) =>
                      c.categoria.toLowerCase().contains('comida') ||
                      c.categoria.toLowerCase().contains('delivery') ||
                      c.categoria.toLowerCase().contains('restaurante'))
                  .fold<double>(0, (acc, c) => acc + c.total.abs());

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (guess != null && guess! > 0 && deliveryCat > 0) ...[
                    Text(
                      'creías gastar',
                      style: AppText.body(15, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCLP(guess!),
                      style: AppText.amount(28, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'en realidad gastaste',
                      style: AppText.body(15, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCLP(deliveryCat),
                      style: AppText.amount(36,
                          color: deliveryCat > guess!
                              ? AppColors.negative
                              : AppColors.positive),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'en comida y delivery',
                      style: AppText.body(14, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    Text(
                      'tus datos están listos',
                      style: AppText.display(26, weight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'pregúntame cualquier cosa sobre tu plata',
                      style: AppText.body(15, color: AppColors.textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              );
            },
          ),
          const Spacer(),
          FilledButton(
            onPressed: onChat,
            child: Text(
              'pregúntale a tu plata',
              style: AppText.body(16, weight: FontWeight.w600, color: AppColors.onPrimary),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onDashboard,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.text,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'ver mi dashboard',
              style: AppText.body(16, weight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Shared shell ──────────────────────────────────────────────────────────────

class _StepShell extends StatelessWidget {
  final Widget child;
  const _StepShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 0),
      child: child,
    );
  }
}
