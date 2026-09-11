import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

enum GlassShape { circle, capsule }

/// iOS 26 Liquid Glass surface behind [child]: Apple's native SwiftUI
/// `glassEffect` (ios/Runner/LiquidGlassView.swift), so it really refracts the
/// animated header behind it. Flutter draws [child] on top and handles taps;
/// the native view ignores touches.
///
/// Off iOS (e.g. the web build) it falls back to a translucent white fill.
class LiquidGlass extends StatelessWidget {
  const LiquidGlass({
    super.key,
    required this.shape,
    required this.child,
    this.clear = false,
    this.fallbackAlpha = 0.10,
  });

  final GlassShape shape;
  final Widget child;

  /// Use Apple's more see-through `.clear` glass instead of `.regular`.
  final bool clear;

  /// White fill opacity where native glass isn't available.
  final double fallbackAlpha;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return DecoratedBox(
        decoration: ShapeDecoration(
          color: Colors.white.withValues(alpha: fallbackAlpha),
          shape: shape == GlassShape.circle
              ? const CircleBorder()
              : const StadiumBorder(),
        ),
        child: child,
      );
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: UiKitView(
            viewType: 'liquid_glass',
            creationParams: {'shape': shape.name, 'clear': clear},
            creationParamsCodec: const StandardMessageCodec(),
            hitTestBehavior: PlatformViewHitTestBehavior.transparent,
          ),
        ),
        child,
      ],
    );
  }
}
