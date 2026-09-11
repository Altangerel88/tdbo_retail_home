import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// An icon exported from the Figma frame (`assets/icons/<name>.svg`), drawn at
/// its designed outer box. Each export keeps its frame's own viewBox, so the
/// glyph's inner padding matches the design without extra insets.
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, required this.size});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) =>
      SvgPicture.asset('assets/icons/$name.svg', width: size, height: size);
}
