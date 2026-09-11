import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import 'app_icon.dart';

/// Floating "Nav Bar - Home" (74444:14489): a 358×68 glass capsule — white @18%
/// over a light backdrop blur, with a bright rim — and a sliding white @35%
/// active pill. The active tab's icon sits on a yellow disc, as home does in
/// the design.
class HomeNavBar extends StatelessWidget {
  const HomeNavBar({super.key, required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    ('nav_home', 'Нүүр'),
    ('nav_qr', 'QR төлбөр'),
    ('nav_transfer', 'Шилжүүлэг'),
    ('nav_services', 'Үйлчилгээ'),
  ];

  static const double _height = 68;
  static const double _inset = 4;
  static const double _gap = 8;
  static const _radius = BorderRadius.all(Radius.circular(_height / 2));

  @override
  Widget build(BuildContext context) {
    final width = math.min(358.0, MediaQuery.sizeOf(context).width - 32);
    final slot =
        (width - _inset * 2 - _gap * (_items.length - 1)) / _items.length;

    return CustomPaint(
      painter: const _OuterShadow(),
      child: ClipRRect(
        borderRadius: _radius,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
          child: Container(
            width: width,
            height: _height,
            color: Colors.white.withValues(alpha: 0.18),
            // Rim as a foreground layer so the border doesn't inset the pill.
            foregroundDecoration: BoxDecoration(
              borderRadius: _radius,
              border: Border.all(color: Colors.white.withValues(alpha: 0.55)),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  left: _inset + index * (slot + _gap),
                  top: _inset,
                  width: slot,
                  height: _height - _inset * 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(_inset),
                  child: Row(
                    children: [
                      for (var i = 0; i < _items.length; i++) ...[
                        if (i > 0) const SizedBox(width: _gap),
                        SizedBox(
                          width: slot,
                          child: _NavItem(
                            icon: _items[i].$1,
                            label: _items[i].$2,
                            active: i == index,
                            onTap: () => onChanged(i),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          children: [
            const SizedBox(height: 8.5),
            SizedBox.square(dimension: 24, child: _glyph()),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              style: mr(
                12,
                active ? FontWeight.w700 : FontWeight.w500,
                T.black,
                ls: -0.48,
                height: 1.074,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glyph() {
    // The design only exports home in its active state (disc baked in); its
    // bare glyph is split out for the inactive state.
    if (icon == 'nav_home') {
      return AppIcon(active ? 'nav_home' : 'nav_home_glyph', size: 24);
    }
    if (!active) return AppIcon(icon, size: 24);
    return DecoratedBox(
      decoration: const BoxDecoration(color: T.yellow, shape: BoxShape.circle),
      child: Center(child: AppIcon(icon, size: 18)),
    );
  }
}

/// Figma drop shadow 0/0/4 @13% — drawn only outside the capsule, so it
/// doesn't grey the translucent fill (Flutter's BoxShadow would).
class _OuterShadow extends CustomPainter {
  const _OuterShadow();

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(size.height / 2),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0x21000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 2),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
