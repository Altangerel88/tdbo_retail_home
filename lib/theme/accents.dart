import 'package:flutter/material.dart';

import 'tokens.dart';

/// Light or dark mode, for picking an accent's brand value.
enum AccentMode { light, dark }

/// One of the app's accent colours, with its brand value for each mode.
class Accent {
  const Accent(this.id, this.label, this.light, this.dark);

  final String id;

  /// Mongolian name, as the accent table gives it.
  final String label;

  /// Brand value in light mode (Цайвар горим) and dark mode (Бараан горим).
  final Color light, dark;

  Color of(AccentMode mode) => mode == AccentMode.light ? light : dark;
}

/// The accent table, in its order. Standard's dark value is the brand
/// yellow the header was designed in.
const accents = [
  Accent('standard', 'Үндсэн', Color(0xFF0054A6), Color(0xFFFCC006)),
  Accent('pink', 'Ягаан', Color(0xFFD81B60), Color(0xFFD81B60)),
  Accent('darkBlue', 'Хар цэнхэр', Color(0xFF102751), Color(0xFF8AB4F8)),
  Accent('purple', 'Нил ягаан', Color(0xFF6A1B9A), Color(0xFFCE93D8)),
  Accent('emerald', 'Ногоон', Color(0xFF0E6447), Color(0xFF146E49)),
  Accent('beige', 'Бор', Color(0xFFA68A64), Color(0xFFD8C3A5)),
  Accent('orange', 'Улбар шар', Color(0xFFE65100), Color(0xFFFF9F43)),
  Accent('olive', 'Зэрлэг ногоон', Color(0xFF6B8E23), Color(0xFFB5C77A)),
];

/// Recolours a header background drawn in brand yellow on [T.inkDeep].
///
/// Every pixel of those backgrounds is a blend of the two (the thread, the
/// fill, the glow and their edges), so its red channel alone says how far
/// along it is, and one matrix maps the whole ramp onto a new pair:
/// - dark mode keeps the charcoal ground and draws in the accent's dark
///   value;
/// - light mode makes the ground the accent's light value and draws in
///   white, which every light value carries the header's white text on.
///
/// Returns null for the colours the backgrounds are drawn in, so standard in
/// dark mode costs nothing.
ColorFilter? accentFilter(Accent accent, AccentMode mode) {
  final ground = mode == AccentMode.light ? accent.light : T.inkDeep;
  final line = mode == AccentMode.light ? Colors.white : accent.dark;
  if (ground == T.inkDeep && line == T.yellow) return null;

  final r0 = _byte(T.inkDeep.r), r1 = _byte(T.yellow.r);
  List<double> channel(double g, double l) {
    final k = (_byte(l) - _byte(g)) / (r1 - r0);
    return [k, 0, 0, 0, _byte(g) - r0 * k];
  }

  return ColorFilter.matrix([
    ...channel(ground.r, line.r),
    ...channel(ground.g, line.g),
    ...channel(ground.b, line.b),
    0,
    0,
    0,
    1,
    0,
  ]);
}

double _byte(double channel) => channel * 255;
