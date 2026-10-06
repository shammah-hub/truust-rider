import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

import '../theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════
//  APP LOADER (DELIVERY) — orbiting-coin loader with a package/box
//  icon at the center, matching the delivery app's identity.
//
//  This theme only defines a single gold `accent` (no gold ramp
//  like the main app's goldDeep/goldBase/goldLight), so the three
//  coins use `accent` at three opacity levels instead — same
//  three-dot orbit rhythm, adapted to what this theme actually has.
//
//  Usage:
//    const AppLoader()                    // default 52px box
//    const AppLoader(size: 80)            // bigger box
//    AppLoader(repeat: controller.isLoading, animate: controller.isDragging)
// ═══════════════════════════════════════════════════════════════

class AppLoader extends StatefulWidget {
  /// Width/height of the loader's bounding box. Defaults to 52.
  final double size;

  /// Kept for API compatibility with the previous Lottie-based
  /// AppLoader — unused now that this draws its own geometry.
  final double scale;

  /// Kept for API compatibility — unused now that this is a
  /// custom-drawn widget rather than a Lottie asset.
  final String asset;

  final bool repeat;
  final bool animate;

  const AppLoader({
    super.key,
    this.size = 62,
    this.scale = 3.0,
    this.asset = '',
    this.repeat = true,
    this.animate = true,
  });

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static const List<double> _coinOpacities = [1.0, 0.7, 0.45];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.animate) {
      widget.repeat ? _ctrl.repeat() : _ctrl.forward();
    }
  }

  @override
  void didUpdateWidget(covariant AppLoader old) {
    super.didUpdateWidget(old);
    if (widget.animate && !_ctrl.isAnimating) {
      widget.repeat ? _ctrl.repeat() : _ctrl.forward();
    } else if (!widget.animate && _ctrl.isAnimating) {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final packageSize = size * 0.42;
    final coinSize = size * 0.16;
    final orbitRadius = (size - coinSize) / 2;

    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Central package icon — flips black/white with theme
              // mode, matching every other icon in the app.
              Icon(
                Iconsax.box,
                size: packageSize,
                color: AppTheme.ink(Theme.of(context).brightness == Brightness.dark),
              ),

              // Three coins orbiting 120° apart, same accent gold
              // at descending opacity.
              for (int i = 0; i < 3; i++)
                _OrbitingCoin(
                  angle: (_ctrl.value * 2 * math.pi) + (i * (2 * math.pi / 3)),
                  radius: orbitRadius,
                  coinSize: coinSize,
                  color: AppTheme.accent.withOpacity(_coinOpacities[i]),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _OrbitingCoin extends StatelessWidget {
  final double angle;
  final double radius;
  final double coinSize;
  final Color color;

  const _OrbitingCoin({
    required this.angle,
    required this.radius,
    required this.coinSize,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final dx = radius * math.cos(angle);
    final dy = radius * math.sin(angle);
    return Transform.translate(
      offset: Offset(dx, dy),
      child: Container(
        width: coinSize,
        height: coinSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
