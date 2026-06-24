import 'package:flutter/material.dart';
import '../models/transaction.dart';

class TransactionTile extends StatelessWidget {
  final Transaction t;
  const TransactionTile({super.key, required this.t});

  String _monto(double m) {
    final neg = m < 0;
    final abs = m.abs().toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+$)'), (mm) => '${mm[1]}.');
    return '${neg ? '-' : '+'}\$$abs';
  }

  @override
  Widget build(BuildContext context) {
    final gasto = t.monto < 0;
    return ListTile(
      dense: true,
      title: Text(t.descripcion, style: const TextStyle(color: Color(0xFFE6EDF3))),
      subtitle: Text('${t.fecha} · ${t.banco}',
          style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12)),
      trailing: Text(_monto(t.monto),
          style: TextStyle(
              color: gasto ? const Color(0xFFF85149) : const Color(0xFF00C896),
              fontWeight: FontWeight.w600)),
    );
  }
}
