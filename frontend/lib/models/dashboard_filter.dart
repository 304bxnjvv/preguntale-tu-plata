import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardFilter {
  final int? dias;
  final String? tipo; // 'ingreso' | 'gasto' | null (ambos)
  const DashboardFilter({this.dias = 30, this.tipo});

  @override
  bool operator ==(Object other) =>
      other is DashboardFilter && other.dias == dias && other.tipo == tipo;

  @override
  int get hashCode => Object.hash(dias, tipo);
}

final dashboardFilterProvider =
    StateProvider<DashboardFilter>((ref) => const DashboardFilter(dias: 30));
