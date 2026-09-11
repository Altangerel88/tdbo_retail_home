import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../theme/tokens.dart';

/// Header background drawn by the silk fragment shader
/// (shaders/navy_silk.frag) in the TDB brand colors: charcoal #242424 folds
/// with a #FCC006 sheen that slowly shifts.
///
/// The shader's uniforms, in order: uSize (width, height), uTime (seconds),
/// uIntensity (motion speed, 1 = as authored), then four RGB colors from
/// darkest to brightest — see [_HeaderShaderState._palette]. With the system
/// "reduce motion" setting on, the silk holds still.
class HeaderShader extends StatefulWidget {
  const HeaderShader({super.key, this.intensity = 1.0});

  /// Motion speed passed to the shader's `uIntensity`.
  final double intensity;

  @override
  State<HeaderShader> createState() => _HeaderShaderState();
}

class _HeaderShaderState extends State<HeaderShader>
    with SingleTickerProviderStateMixin {
  // Compiled once and shared by every instance.
  static final Future<ui.FragmentProgram> _program =
      ui.FragmentProgram.fromAsset('shaders/navy_silk.frag');

  /// #FCC006 at [strength] mixed into #242424, as an opaque color.
  static Color _sheen(double strength) =>
      Color.alphaBlend(T.yellow.withValues(alpha: strength), T.ink);

  // Silk ramp, darkest → brightest: deep charcoal, brand charcoal and two gold
  // sheens. The shader's brightest pixel is 12% uBase + 22% uMid + 66% uLift,
  // about 30% yellow here, which keeps the 72%-white IBAN above 4.5:1
  // wherever a highlight drifts.
  static final _palette = [T.inkDeep, T.ink, _sheen(0.22), _sheen(0.38)];

  late final Ticker _ticker = createTicker(_tick);
  final _time = ValueNotifier<double>(0);
  double _offset = 0; // seconds already played before a pause
  ui.FragmentShader? _shader;

  @override
  void initState() {
    super.initState();
    _program.then((program) {
      if (mounted) setState(() => _shader = program.fragmentShader());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "reduce motion" setting.
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _ticker.isActive) {
      _offset = _time.value;
      _ticker.stop();
    } else if (!still && !_ticker.isActive) {
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) => _time.value =
      _offset + elapsed.inMicroseconds / Duration.microsecondsPerSecond;

  @override
  void dispose() {
    _ticker.dispose();
    _time.dispose();
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shader = _shader;
    // Plain charcoal for the frame or two before the shader has compiled.
    if (shader == null) return const ColoredBox(color: T.ink);
    return RepaintBoundary(
      child: CustomPaint(
        painter: _SilkPainter(shader, _time, widget.intensity, _palette),
        size: Size.infinite,
      ),
    );
  }
}

class _SilkPainter extends CustomPainter {
  _SilkPainter(this.shader, this.time, this.intensity, this.palette)
    : super(repaint: time);

  final ui.FragmentShader shader;
  final ValueListenable<double> time;
  final double intensity;
  final List<Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, time.value)
      ..setFloat(3, intensity);
    for (var i = 0; i < palette.length; i++) {
      final c = palette[i];
      shader
        ..setFloat(4 + i * 3, c.r)
        ..setFloat(5 + i * 3, c.g)
        ..setFloat(6 + i * 3, c.b);
    }
    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(_SilkPainter old) =>
      old.shader != shader || old.intensity != intensity;
}
