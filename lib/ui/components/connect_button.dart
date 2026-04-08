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

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200));
    _breathController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2500));
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
      _pulseController.repeat(reverse: true);
      _breathController.stop();
    } else if (widget.isConnected) {
      _rotationController.stop();
      _pulseController.stop();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final breath = widget.isConnected
        ? Tween(begin: 1.0, end: 1.02)
            .animate(CurvedAnimation(parent: _breathController, curve: Curves.easeInOut))
            .value
        : 1.0;

    return AnimatedBuilder(
      animation: Listenable.merge([_rotationController, _pulseController, _breathController]),
      builder: (context, _) {
        return Transform.scale(
          scale: breath,
          child: SizedBox(
            width: 200,
            height: 200,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onTap,
                customBorder: const CircleBorder(),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _buildGlow(),
                    if (widget.isConnecting) _buildRotatingArc(),
                    if (widget.isConnecting) _buildPulseRing(),
                    if (widget.isConnected) _buildConnectedRing(),
                    _buildOuterRing(),
                    _buildMainButton(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGlow() {
    final color = widget.isConnected
        ? const Color(0xFF00E676)
        : widget.isConnecting
            ? const Color(0xFF00E5FF)
            : const Color(0xFF6C63FF);
    return Container(
      width: 200, height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 40, spreadRadius: 5),
        ],
      ),
    );
  }

  Widget _buildOuterRing() {
    final color = widget.isConnected
        ? const Color(0xFF00E676)
        : widget.isConnecting
            ? const Color(0xFF00E5FF)
            : const Color(0xFF6C63FF);
    return Container(
      width: 178, height: 178,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
      ),
    );
  }

  Widget _buildRotatingArc() {
    return Transform.rotate(
      angle: _rotationController.value * 2 * math.pi,
      child: CustomPaint(
        size: const Size(186, 186),
        painter: _ArcPainter(
          color1: const Color(0xFF00E5FF),
          color2: const Color(0xFF6C63FF),
        ),
      ),
    );
  }

  Widget _buildPulseRing() {
    final alpha = Tween(begin: 0.15, end: 0.5)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut))
        .value;
    return Container(
      width: 184, height: 184,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: alpha), width: 2.5),
      ),
    );
  }

  Widget _buildConnectedRing() {
    return Container(
      width: 184, height: 184,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3), width: 2),
      ),
    );
  }

  Widget _buildMainButton() {
    final List<Color> colors;
    if (widget.isConnected) {
      colors = [const Color(0xFF00E676), const Color(0xFF00C853)];
    } else if (widget.isConnecting) {
      colors = [const Color(0xFF00E5FF), const Color(0xFF0091EA)];
    } else {
      colors = [const Color(0xFF8B85FF), const Color(0xFF5C55D4)];
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      width: 150, height: 150,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [colors[0], colors[1]],
          center: const Alignment(-0.2, -0.3),
        ),
        boxShadow: [
          BoxShadow(color: colors[0].withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: const Center(
        child: Icon(Icons.power_settings_new_rounded, size: 52, color: Colors.white),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final Color color1, color2;
  _ArcPainter({required this.color1, required this.color2});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [color1, color2, color1.withValues(alpha: 0)],
        stops: const [0.0, 0.35, 0.7],
      ).createShader(rect);
    canvas.drawArc(rect.deflate(2), 0, math.pi * 1.4, false, paint);
  }

  @override
  bool shouldRepaint(covariant _ArcPainter old) => false;
}
