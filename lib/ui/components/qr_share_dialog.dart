import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr/qr.dart';

import '../theme/app_theme.dart';

class QrShareDialog extends StatelessWidget {
  final String data;
  final String title;

  const QrShareDialog({
    super.key,
    required this.data,
    this.title = 'Поделиться',
  });

  static void show(BuildContext context, {required String data, String? title}) {
    if (data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ссылка подписки не найдена'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => QrShareDialog(data: data, title: title ?? 'Поделиться'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.primaryGradient.createShader(bounds),
            child: const Icon(Icons.qr_code_2, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Real QR Code
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 220,
              height: 220,
              child: CustomPaint(
                painter: _QrCodePainter(data: data),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Hint
          const Text(
            'Отсканируйте QR с другого устройства в Tunnex\nили передайте ссылку — в ней все настройки',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
          ),
          const SizedBox(height: 12),
          // URL
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              data,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
                fontFamily: 'monospace',
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: data));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Ссылка скопирована'),
                    duration: Duration(seconds: 1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Копировать ссылку'),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }
}

class _QrCodePainter extends CustomPainter {
  final String data;
  _QrCodePainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);
    final moduleCount = qrCode.moduleCount;
    final cellSize = size.width / moduleCount;

    final paint = Paint()..color = const Color(0xFF1A1A2E);

    for (int y = 0; y < moduleCount; y++) {
      for (int x = 0; x < moduleCount; x++) {
        if (qrImage.isDark(y, x)) {
          canvas.drawRect(
            Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrCodePainter old) => old.data != data;
}
