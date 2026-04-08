import 'dart:math' as math;

import 'package:flutter/material.dart';

class ConnectButton extends StatefulWidget {
  final bool isConnected;
  final bool isConnecting;
  final VoidCallback onTap;

  const ConnectButton({
    super.key,
    required this.isConnected,
    required this.isConnecting,
    required this.onTap,
  });

  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late AnimationController _breathController;
  late AnimationController _pressController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1800));
    _breathController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
    _pressController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _updateAnimations();
  }

  @override
  void didUpdateWidget(ConnectButton old) {
    super.didUpdateWidget(old);
    if (old.isConnected != widget.isConnected ||
        old.isConnecting != widget.isConnecting) {
      _updateAnimations();
    }
  }

  void _updateAnimations() {
    if (widget.isConnecting) {
      _rotationController.repeat();
      _pulseController.stop();
      _breathController.stop();
    } else if (widget.isConnected) {
      _rotationController.stop();
      _pulseController.repeat(reverse: true);
      _breathController.repeat(reverse: true);
    } else {
      _rotationController.stop();
      _pulseController.stop();
      _breathController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    _breathController.dispose();
    _pressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressController.forward(),
      onTapUp: (_) {
        _pressController.reverse();
        widget.onTap();
      },
      onTapCancel: () => _pressController.reverse(),
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _rotationController,
          _pulseController,
          _breathController,
          _pressController,
        ]),
        builder: (context, _) {
          final press = Tween(begin: 1.0, end: 0.93)
              .animate(CurvedAnimation(
                  parent: _pressController, curve: Curves.easeInOut))
              .value;
          final breath = widget.isConnected
              ? Tween(begin: 1.0, end: 1.025)
                  .animate(CurvedAnimation(
                      parent: _breathController, curve: Curves.easeInOut))
                  .value
              : 1.0;

          return Transform.scale(
            scale: press * breath,
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow
                  _buildGlow(),
                  // Rotating ring
                  if (widget.isConnecting) _buildRotatingArc(),
                  // Pulse ring (connected)
                  if (widget.isConnected) _buildPulseRing(),
                  // Static outer ring
                  _buildOuterRing(),
                  // Main button
                  _buildMainButton(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGlow() {
    final color = widget.isConnected
        ? const Color(0xFF00E676)
        : const Color(0xFF6C63FF);
    final alpha = widget.isConnected
        ? 0.15 + _pulseController.value * 0.1
        : 0.08;
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: alpha),
            blurRadius: 40,
            spreadRadius: 10,
          ),
        ],
      ),
    );
  }

  Widget _buildOuterRing() {
    final color = widget.isConnected
        ? const Color(0xFF00E676)
        : widget.isConnecting
            ? const Color(0xFF00D4FF)
            : const Color(0xFF6C63FF);
    return Container(
      width: 180,
      height: 180,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
    );
  }

  Widget _buildRotatingArc() {
    return Transform.rotate(
      angle: _rotationController.value * 2 * math.pi,
      child: CustomPaint(
        size: const Size(186, 186),
        painter: _ArcPainter(
          color1: const Color(0xFF6C63FF),
          color2: const Color(0xFF00D4FF),
        ),
      ),
    );
  }

  Widget _buildPulseRing() {
    final alpha = Tween(begin: 0.1, end: 0.4)
        .animate(CurvedAnimation(
            parent: _pulseController, curve: Curves.easeInOut))
        .value;
    return Container(
      width: 186,
      height: 186,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFF00E676).withValues(alpha: alpha),
          width: 2.5,
        ),
      ),
    );
  }

  Widget _buildMainButton() {
    final List<Color> colors;
    if (widget.isConnected) {
      colors = [const Color(0xFF00E676), const Color(0xFF00C853)];
    } else if (widget.isConnecting) {
      colors = [const Color(0xFF7B73FF), const Color(0xFF00B8D4)];
    } else {
      colors = [const Color(0xFF8B85FF), const Color(0xFF5C55D4)];
    }

    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [colors[0], colors[1]],
          center: const Alignment(-0.2, -0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: colors[0].withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: const Center(
        child: Icon(
          Icons.power_settings_new_rounded,
          size: 52,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color1;
  final Color color2;

  _ArcPainter({required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color1, color2, color1.withValues(alpha: 0)],
        stops: const [0.0, 0.4, 0.8],
      ).createShader(rect);

    canvas.drawArc(rect.deflate(2), 0, math.pi * 1.4, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => false;
}
