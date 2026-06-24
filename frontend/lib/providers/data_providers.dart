import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/api_service.dart';
import '../models/summary.dart';
import '../models/transaction.dart';

final apiProvider = Provider<ApiService>((ref) {
  return ApiService(
    token: () => Supabase.instance.client.auth.currentSession?.accessToken,
  );
});

final summaryProvider = FutureProvider<Summary>((ref) {
  return ref.watch(apiProvider).getSummary();
});

final transactionsProvider = FutureProvider<List<Transaction>>((ref) {
  return ref.watch(apiProvider).getTransactions();
});
