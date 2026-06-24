import 'package:flutter/material.dart';
import '../services/api.dart';

class UploadCard extends StatelessWidget {
  final String banco;
  final bool uploading;
  final UploadResult? uploadResult;
  final ValueChanged<String> onBancoChanged;
  final VoidCallback onUpload;

  const UploadCard({
    super.key,
    required this.banco,
    required this.uploading,
    required this.uploadResult,
    required this.onBancoChanged,
    required this.onUpload,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: Color(0xFF8B949E), size: 18),
          const SizedBox(width: 10),
          _BancoDropdown(value: banco, onChanged: onBancoChanged),
          const SizedBox(width: 12),
          _UploadButton(uploading: uploading, result: uploadResult, onTap: onUpload),
          if (uploadResult != null) ...[
            const SizedBox(width: 12),
            Flexible(
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF00C896), size: 16),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${uploadResult!.count} transacciones',
                      style: const TextStyle(
                        color: Color(0xFF00C896),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BancoDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _BancoDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF30363D)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: const Color(0xFF161B22),
          style: const TextStyle(color: Color(0xFFE6EDF3), fontSize: 13),
          isDense: true,
          items: const [
            DropdownMenuItem(value: 'bci', child: Text('BCI')),
            DropdownMenuItem(value: 'santander', child: Text('Santander')),
            DropdownMenuItem(value: 'bancoestado', child: Text('BancoEstado')),
          ],
          onChanged: (v) => v != null ? onChanged(v) : null,
        ),
      ),
    );
  }
}

class _UploadButton extends StatelessWidget {
  final bool uploading;
  final UploadResult? result;
  final VoidCallback onTap;
  const _UploadButton({required this.uploading, required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: uploading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF238636),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF30363D),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
      ),
      icon: uploading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Icon(result == null ? Icons.upload_file : Icons.refresh, size: 16),
      label: Text(uploading
          ? 'Subiendo...'
          : result == null
              ? 'Subir CSV'
              : 'Cambiar CSV'),
    );
  }
}
