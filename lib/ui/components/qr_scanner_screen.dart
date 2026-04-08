import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _hasResult = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Сканировать QR'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller,
              builder: (_, state, __) {
                return Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          // Overlay with cutout
          _buildOverlay(),
          // Hint text
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Text(
              'Наведите камеру на QR-код\nподписки или сервера',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasResult) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final value = barcode.rawValue!;
    // Accept subscription URLs and protocol URIs
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('vless://') ||
        value.startsWith('vmess://') ||
        value.startsWith('trojan://') ||
        value.startsWith('ss://') ||
        value.startsWith('tunnex://')) {
      _hasResult = true;
      Navigator.pop(context, value);
    }
  }

  Widget _buildOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scanSize = constraints.maxWidth * 0.7;
        final top = (constraints.maxHeight - scanSize) / 2 - 40;
        final left = (constraints.maxWidth - scanSize) / 2;
        const overlayColor = Colors.black54;

        return Stack(
          children: [
            // Top dark area
            Positioned(top: 0, left: 0, right: 0, height: top,
              child: Container(color: overlayColor)),
            // Bottom dark area
            Positioned(top: top + scanSize, left: 0, right: 0, bottom: 0,
              child: Container(color: overlayColor)),
            // Left dark area
            Positioned(top: top, left: 0, width: left, height: scanSize,
              child: Container(color: overlayColor)),
            // Right dark area
            Positioned(top: top, right: 0, width: left, height: scanSize,
              child: Container(color: overlayColor)),
            // Corner brackets
            Positioned(
              top: top,
              left: left,
              child: SizedBox(
                width: scanSize,
                height: scanSize,
                child: CustomPaint(
                  painter: _CornerPainter(
                    color: AppColors.primary,
                    cornerLength: 30,
                    strokeWidth: 4,
                    radius: 24,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double cornerLength;
  final double strokeWidth;
  final double radius;

  _CornerPainter({
    required this.color,
    required this.cornerLength,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;
    final cl = cornerLength;
    final r = radius;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, cl)
        ..lineTo(0, r)
        ..quadraticBezierTo(0, 0, r, 0)
        ..lineTo(cl, 0),
      paint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(w - cl, 0)
        ..lineTo(w - r, 0)
        ..quadraticBezierTo(w, 0, w, r)
        ..lineTo(w, cl),
      paint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, h - cl)
        ..lineTo(0, h - r)
        ..quadraticBezierTo(0, h, r, h)
        ..lineTo(cl, h),
      paint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(w - cl, h)
        ..lineTo(w - r, h)
        ..quadraticBezierTo(w, h, w, h - r)
        ..lineTo(w, h - cl),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
