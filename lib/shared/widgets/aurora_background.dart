import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme.dart';

// ─── Aurora Orb ───────────────────────────────────────────────────────────────
/// A single animated radial-gradient orb. Provide an [AnimationController]
/// and this widget will gently breathe / drift.
class AuroraOrb extends StatelessWidget {
  final double size;
  final Color color;
  final Animation<double> animation;
  final Alignment alignment;
  final double opacity;
  final double phase; // 0–1 phase offset for staggered drift

  const AuroraOrb({
    super.key,
    required this.size,
    required this.color,
    required this.animation,
    this.alignment = Alignment.center,
    this.opacity = 0.55,
    this.phase = 0,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final t = (animation.value + phase) % 1.0;
        // Slow sinusoidal drift
        final dx = math.sin(t * 2 * math.pi) * 0.08;
        final dy = math.cos(t * 2 * math.pi * 0.7) * 0.06;
        final scale = 0.92 + math.sin(t * 2 * math.pi * 1.3) * 0.08;

        return Align(
          alignment: Alignment(
            alignment.x + dx,
            alignment.y + dy,
          ),
          child: Transform.scale(
            scale: scale,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    color.withOpacity(opacity),
                    color.withOpacity(opacity * 0.4),
                    color.withOpacity(0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Aurora Background ────────────────────────────────────────────────────────
/// Full-screen animated aurora. Wrap your page content on top.
/// Usage:
///   Stack(children: [
///     const Positioned.fill(child: AuroraBackground()),
///     YourContent(),
///   ])
class AuroraBackground extends StatefulWidget {
  /// Override base background colour. Defaults to AppColors.darkBg in dark,
  /// AppColors.lightBg in light.
  final Color? backgroundColor;

  /// Orb intensity multiplier (0.0–1.0). Smaller = more subtle.
  final double intensity;

  const AuroraBackground({super.key, this.backgroundColor, this.intensity = 1.0});

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = widget.backgroundColor ??
        (isDark ? AppColors.darkBg : AppColors.lightBg);

    // Orb opacity tuned per theme
    final orbOpacity = (isDark ? 0.55 : 0.35) * widget.intensity;

    return Container(
      color: bg,
      child: Stack(
        children: [
          // ── Aurora orb 1 — violet top-left ─────────────────────────────────
          AuroraOrb(
            animation: _ctrl,
            color: AppColors.auroraViolet,
            size: MediaQuery.of(context).size.width * 0.8,
            alignment: const Alignment(-0.7, -0.8),
            opacity: orbOpacity,
            phase: 0.0,
          ),

          // ── Aurora orb 2 — cyan bottom-right ───────────────────────────────
          AuroraOrb(
            animation: _ctrl,
            color: AppColors.auroraCyan,
            size: MediaQuery.of(context).size.width * 0.7,
            alignment: const Alignment(0.8, 0.7),
            opacity: orbOpacity * 0.85,
            phase: 0.25,
          ),

          // ── Aurora orb 3 — pink top-right ──────────────────────────────────
          AuroraOrb(
            animation: _ctrl,
            color: AppColors.auroraPink,
            size: MediaQuery.of(context).size.width * 0.55,
            alignment: const Alignment(0.7, -0.6),
            opacity: orbOpacity * 0.7,
            phase: 0.5,
          ),

          // ── Aurora orb 4 — indigo bottom-left ──────────────────────────────
          AuroraOrb(
            animation: _ctrl,
            color: AppColors.auroraIndigo,
            size: MediaQuery.of(context).size.width * 0.6,
            alignment: const Alignment(-0.6, 0.65),
            opacity: orbOpacity * 0.75,
            phase: 0.75,
          ),
        ],
      ),
    );
  }
}
