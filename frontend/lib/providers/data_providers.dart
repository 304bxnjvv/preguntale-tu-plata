import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../models/chat_message.dart';
import '../models/summary.dart';
import '../models/transaction.dart';
import '../models/dashboard_filter.dart';
import '../models/insights.dart';
import '../models/finscore.dart';
import '../models/tarjeta.dart';
import '../models/presupuesto.dart';
import '../models/meta.dart';

export '../models/dashboard_filter.dart' show DashboardFilter, dashboardFilterProvider;
export '../services/api_service.dart' show Subscription;
export '../models/finscore.dart' show FinScore, FinFactor;
export '../models/tarjeta.dart' show TarjetaEstado, Cuota;
export '../models/presupuesto.dart' show PresupuestoEstado;
export '../models/meta.dart' show Meta;

final apiProvider = Provider<ApiService>((ref) {
  return ApiService(
    token: () => Supabase.instance.client.auth.currentSession?.accessToken,
  );
});

final summaryProvider = FutureProvider<Summary>((ref) {
  final filter = ref.watch(dashboardFilterProvider);
  return ref.watch(apiProvider).getSummary(dias: filter.dias, tipo: filter.tipo);
});

final transactionsProvider = FutureProvider<List<Transaction>>((ref) {
  final filter = ref.watch(dashboardFilterProvider);
  return ref.watch(apiProvider).getTransactions(dias: filter.dias, tipo: filter.tipo);
});

final chatHistoryProvider = FutureProvider<List<ChatMessage>>((ref) {
  return ref.watch(apiProvider).getChatHistory();
});

final suscripcionesProvider = FutureProvider<Suscripciones>((ref) {
  return ref.watch(apiProvider).getSuscripciones();
});

final comparativoProvider = FutureProvider<Comparativo>((ref) {
  return ref.watch(apiProvider).getComparativo();
});

final subscriptionProvider = FutureProvider<Subscription>((ref) {
  return ref.watch(apiProvider).getSubscription();
});

final finScoreProvider = FutureProvider<FinScore>((ref) {
  return ref.watch(apiProvider).getFinScore();
});

final tarjetaProvider = FutureProvider<TarjetaEstado>((ref) {
  return ref.watch(apiProvider).getTarjeta();
});

final presupuestosProvider = FutureProvider<List<PresupuestoEstado>>((ref) {
  return ref.watch(apiProvider).getPresupuestos();
});

final metasProvider = FutureProvider<List<Meta>>((ref) {
  return ref.watch(apiProvider).getMetas();
});
