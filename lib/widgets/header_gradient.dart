import 'package:animate_gradient/animate_gradient.dart';
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Animated brand background behind the header, using the animate_gradient
/// package (github.com/Vikaskumar75/Animated-Gradient): a TDB yellow
/// (#FCC006) glow over a deepened TDB charcoal ([T.inkDeep], from #242424).
///
/// The glow swings from the top-right corner across to the top-left and back
/// (the gradient clamps, so the area behind its lit end takes the lit color),
/// breathing between two strengths. Yellow is mixed into the charcoal rather
/// than used at full strength, because white text and icons on pure #FCC006
/// are unreadable (1.6:1). Full yellow stays on the "Дансны хуулга" button.
///
/// The package restarts its animation whenever it is rebuilt, so use this as
/// a `const` widget: Flutter skips identical const widgets on parent rebuilds,
/// so tapping the eye or a nav tab won't reset the motion.
class HeaderGradient extends StatelessWidget {
  const HeaderGradient({super.key});

  /// #FCC006 at [strength] mixed into the deep charcoal, as an opaque color.
  static Color _glow(double strength) =>
      Color.alphaBlend(T.yellow.withValues(alpha: strength), T.inkDeep);

  // Colors run from the lit corner to the far corner, and the gradient fades
  // from `_primary` to `_secondary` and back. The 45% glow only sits behind
  // the status bar and bell; text areas stay at 30% or less, which keeps the
  // 72%-white IBAN above 4.5:1.
  static final _primary = [_glow(0.45), _glow(0.12), T.inkDeep, T.inkDeep];
  static final _secondary = [_glow(0.30), _glow(0.06), T.inkDeep, T.inkDeep];

  @override
  Widget build(BuildContext context) {
    // Respect the system "reduce motion" setting with a still gradient.
    if (MediaQuery.disableAnimationsOf(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: _primary,
          ),
        ),
      );
    }
    // Can't be const itself: the package's constructor asserts on list lengths.
    return AnimateGradient(
      primaryColors: _primary,
      secondaryColors: _secondary,
      primaryBegin: Alignment.topRight,
      primaryEnd: Alignment.topCenter,
      secondaryBegin: Alignment.bottomLeft,
      secondaryEnd: Alignment.bottomRight,
      duration: const Duration(seconds: 8),
    );
  }
}
