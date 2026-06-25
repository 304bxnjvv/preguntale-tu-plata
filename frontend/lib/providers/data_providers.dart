import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../models/chat_message.dart';
import '../models/summary.dart';
import '../models/transaction.dart';
import '../models/dashboard_filter.dart';

export '../models/dashboard_filter.dart' show DashboardFilter, dashboardFilterProvider;

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
