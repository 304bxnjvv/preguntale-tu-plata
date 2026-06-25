import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme.dart';
import '../widgets/orb.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  static const _benefits = [
    (icon: Icons.chat_bubble_outline_rounded, text: 'chat ilimitado con tu plata'),
    (icon: Icons.upload_file_rounded, text: 'todas tus cartolas, sin límite'),
    (icon: Icons.autorenew_rounded, text: 'suscripciones detectadas automáticamente'),
    (icon: Icons.bar_chart_rounded, text: 'comparativos mes a mes'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textMuted),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Center(child: Orb(size: 80)),
              const SizedBox(height: 28),
              Text(
                'hazte premium',
                style: AppText.display(34, weight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              // Price
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatCLP(3990),
                    style: AppText.amount(40, color: AppColors.primary),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 4),
                    child: Text(
                      '/mes',
                      style: AppText.body(16, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              // Benefits glass card
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
                    Text('qué incluye', style: AppText.label(AppColors.accent)),
                    const SizedBox(height: 16),
                    for (final b in _benefits) ...[
                      Row(
                        children: [
                          Icon(b.icon, size: 18, color: AppColors.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(b.text, style: AppText.body(15)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.push('/suscripcion/consentimiento'),
                child: Text(
                  'suscribirme',
                  style: AppText.body(16, weight: FontWeight.w600, color: AppColors.onPrimary),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.pop(),
                child: Text(
                  'ahora no',
                  style: AppText.body(15, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
