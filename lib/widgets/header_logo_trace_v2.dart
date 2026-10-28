import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Header background, v2 of the logo thread. v1 is `HeaderLogoTrace` in
/// header_logo_trace.dart, kept as it was.
///
/// The same yellow hairline runs in from the left along the header's lower
/// edge and draws the TDB mark in one unbroken stroke. Here the knot is
/// larger, sits on the left and leans 75° to the left. Once tied it fills,
/// dissolves into the header toward its upper right, and turns a quarter.
/// Then it unties, and the thread runs out the full width to the right.
/// Loops every 12 s. With the system "reduce motion" setting on, the
/// finished knot sits still.
class HeaderLogoTraceV2 extends StatefulWidget {
  const HeaderLogoTraceV2({super.key, this.underlap = 0});

  /// How far this background runs under the content below it. The thread
  /// stays above that edge.
  final double underlap;

  @override
  State<HeaderLogoTraceV2> createState() => _HeaderLogoTraceV2State();
}

class _HeaderLogoTraceV2State extends State<HeaderLogoTraceV2>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_Beat.loop * 1000).round()),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "reduce motion" setting.
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _TracePainter(
          _clock,
          underlap: widget.underlap,
          still: MediaQuery.disableAnimationsOf(context),
        ),
        size: Size.infinite,
      ),
    );
  }
}

// The v2 look. However it's placed, the knot's lowest point sits on the thread.
const _knotWidth = 0.74; // of the header's width
const _knotX = 0.30; // knot centre, of the header's width
const _tilt = -75 * math.pi / 180; // 75° to the left (counter-clockwise)
// How far the knot's upper right fades: while the thread draws, and once the
// knot has filled. It sits behind the text, so it never shows at full strength.
const _dissolveDrawing = 0.45, _dissolveTied = 0.85;

/// Beats of the loop, in seconds.
class _Beat {
  static const loop = 12.0;

  // Tie: the head runs in and round the whole circuit. The tail follows only
  // as far as the knot, drawing the lead-in back into it.
  static const tieEnd = 4.6;
  static const tailStart = 0.4, tailEnd = 1.9;
  static const sparkIn = 0.25, sparkOutStart = 4.2;

  // The knot fills and dissolves as the circuit closes, then turns a quarter.
  static const fillStart = 3.6, fillEnd = 5.2;
  static const turnStart = 5.2, turnEnd = 6.8;

  // Untie: the head pulls out to the right and the tail unwinds the circuit
  // after it. The rest of the loop is empty.
  static const untieStart = 7.4, unfillEnd = 8.6, pullEnd = 8.9;
  static const untieEnd = 11.0;
}

/// One moment of the loop.
class _Frame {
  const _Frame({
    required this.tail,
    required this.head,
    required this.fill,
    required this.turn,
    required this.spark,
  });

  /// Visible stretch of the thread, as distances along it.
  final double tail, head;

  /// Knot fill and dissolve, 0–1.
  final double fill;

  /// Knot rotation on top of its tilt, radians clockwise.
  final double turn;

  /// Glow on the moving head, 0–1.
  final double spark;
}

class _TracePainter extends CustomPainter {
  _TracePainter(this.clock, {required this.underlap, required this.still})
    : super(repaint: clock);

  final Animation<double> clock;
  final double underlap;
  final bool still;

  // Geometry depends only on the size; rebuilt when the header resizes.
  static _Thread? _thread;

  static const _lineWidth = 1.25;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = T.inkDeep);
    if (size.isEmpty) return;

    var th = _thread;
    if (th == null || th.size != size || th.underlap != underlap) {
      th = _thread = _Thread(size, underlap);
    }
    final f = still ? th.finished : _frameAt(clock.value * _Beat.loop, th);
    final c = th.center;

    void turnKnot() {
      if (f.turn == 0) return;
      canvas
        ..translate(c.dx, c.dy)
        ..rotate(f.turn)
        ..translate(-c.dx, -c.dy);
    }

    // Gradient ends in world space, unturned so they stay put while the knot
    // turns: the knot is strongest at its lower left, where the thread joins,
    // and dissolves toward its upper right.
    Offset fixed(Offset p) => c + _turn(p - c, -f.turn);
    final strong = fixed(th.strong), faint = fixed(th.faint);

    // A faint light behind the knot once it has filled.
    if (f.fill > 0) {
      final r = _extent * th.unit;
      canvas.drawCircle(
        c,
        r * 1.2,
        Paint()
          ..shader = ui.Gradient.radial(c, r * 1.2, [
            T.yellow.withValues(alpha: 0.05 * f.fill),
            T.yellow.withValues(alpha: 0),
          ]),
      );

      canvas.save();
      turnKnot();
      canvas.drawPath(
        th.knot,
        Paint()
          ..shader = ui.Gradient.linear(strong, faint, [
            T.yellow.withValues(alpha: 0.13 * f.fill),
            T.yellow.withValues(alpha: 0),
          ]),
      );
      canvas.restore();
    }

    // The thread is stroked opaque into a layer and faded as a whole, so the
    // spots where it crosses itself don't double up. Softer than v1's, since
    // this knot runs behind the text.
    canvas.saveLayer(
      bounds,
      Paint()..color = Color.fromRGBO(0, 0, 0, 0.65 - 0.27 * f.fill),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = T.yellow;

    final lin = th.leadIn.length, knot = th.circuit.length;
    final y = th.lineY;

    // Lead-in, fading toward its tail like a comet.
    if (f.tail < lin && f.head > f.tail) {
      final end = math.min(f.head, lin);
      final x0 = th.leadIn.getTangentForOffset(f.tail)!.position.dx;
      final x1 = th.leadIn.getTangentForOffset(end)!.position.dx;
      canvas.drawPath(
        th.leadIn.extractPath(f.tail, end),
        Paint.from(line)
          ..shader = x1 - x0 < 2
              ? null
              : ui.Gradient.linear(
                  Offset(x0, y),
                  Offset(x1, y),
                  [T.yellow.withValues(alpha: 0), T.yellow],
                  [0, 0.8],
                ),
      );
    }

    // The circuit over the knot, dissolving toward its upper right.
    final a = math.max(f.tail - lin, 0.0), b = math.min(f.head - lin, knot);
    if (b > a) {
      final dissolve =
          _dissolveDrawing + (_dissolveTied - _dissolveDrawing) * f.fill;
      canvas.save();
      turnKnot();
      canvas.drawPath(
        th.circuit.extractPath(a, b),
        Paint.from(line)
          ..shader = ui.Gradient.linear(strong, faint, [
            T.yellow,
            T.yellow.withValues(alpha: 1 - dissolve),
          ]),
      );
      canvas.restore();
    }

    // Lead-out, dissolving toward the right edge.
    final oa = math.max(f.tail - lin - knot, 0.0), ob = f.head - lin - knot;
    if (ob > oa) {
      canvas.drawPath(
        th.leadOut.extractPath(oa, ob),
        Paint.from(line)
          ..shader = ui.Gradient.linear(
            Offset(th.join.dx, y),
            Offset(size.width, y),
            [T.yellow, T.yellow.withValues(alpha: 0)],
            [0.3, 1],
          ),
      );
    }
    canvas.restore();

    // A spark on the head while it draws.
    if (f.spark > 0 && f.head > f.tail) {
      final p = f.head < lin
          ? th.leadIn.getTangentForOffset(f.head)!.position
          : th.circuit.getTangentForOffset(f.head - lin)!.position;
      canvas
        ..drawCircle(
          p,
          9,
          Paint()
            ..shader = ui.Gradient.radial(p, 9, [
              T.yellow.withValues(alpha: 0.5 * f.spark),
              T.yellow.withValues(alpha: 0),
            ]),
        )
        ..drawCircle(
          p,
          1.6,
          Paint()
            ..color = Color.lerp(
              T.yellow,
              Colors.white,
              0.55,
            )!.withValues(alpha: f.spark),
        );
    }
  }

  static _Frame _frameAt(double s, _Thread th) {
    double at(double from, double to) =>
        ((s - from) / (to - from)).clamp(0.0, 1.0);

    final lin = th.leadIn.length, knot = th.circuit.length;
    final total = lin + knot + th.leadOut.length;

    if (s < _Beat.untieStart) {
      return _Frame(
        tail:
            lin *
            Curves.easeInOutCubic.transform(at(_Beat.tailStart, _Beat.tailEnd)),
        head:
            (lin + knot) * Curves.easeInOutSine.transform(at(0, _Beat.tieEnd)),
        fill: Curves.easeOutCubic.transform(at(_Beat.fillStart, _Beat.fillEnd)),
        // Past the turn the knot matches itself again, so it can snap back to 0.
        turn: s < _Beat.turnEnd
            ? math.pi /
                  2 *
                  Curves.easeInOutCubic.transform(
                    at(_Beat.turnStart, _Beat.turnEnd),
                  )
            : 0,
        spark:
            at(0, _Beat.sparkIn) * (1 - at(_Beat.sparkOutStart, _Beat.tieEnd)),
      );
    }
    return _Frame(
      tail:
          lin +
          (total - lin) *
              Curves.easeInOutSine.transform(
                at(_Beat.untieStart, _Beat.untieEnd),
              ),
      head:
          lin +
          knot +
          th.leadOut.length *
              Curves.easeInOutSine.transform(
                at(_Beat.untieStart, _Beat.pullEnd),
              ),
      fill:
          1 -
          Curves.easeInCubic.transform(at(_Beat.untieStart, _Beat.unfillEnd)),
      turn: 0,
      spark: 0,
    );
  }

  @override
  bool shouldRepaint(_TracePainter old) =>
      old.still != still || old.underlap != underlap;
}

// ---------------------------------------------------------------------------
// The TDB mark, in units of half the centre square's side, y down.
//
// Four identical pieces a quarter turn apart. Each is a ring band that ends
// in an arrowhead whose tip sits on a corner of the centre square; each ring
// is cut short where it passes under the ring before it. Measured off the
// brand mark; the nav glyph's paths agree to within 1%.
// ---------------------------------------------------------------------------

const _ring = 2.0; // ring centre, from the mark's centre
const _rIn = 2.32, _rOut = 3.35; // band edges
const _rGap = 3.50; // a ring stops this far from the centre of the ring over it
const _extent = _ring + _rOut; // half the mark's width
const _axis = math.pi / 4; // arrowhead axis, from the ring centre

Offset _turn(Offset p, double a) {
  final c = math.cos(a), s = math.sin(a);
  return Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c);
}

/// Where circles (c1, r1) and (c2, r2) cross, on the side away from the mark's
/// centre.
Offset _meet(Offset c1, double r1, Offset c2, double r2) {
  final d = c2 - c1;
  final dist = d.distance;
  final a = (r1 * r1 - r2 * r2 + dist * dist) / (2 * dist);
  final h = math.sqrt(r1 * r1 - a * a);
  final m = c1 + d * (a / dist);
  final n = Offset(d.dy, -d.dx) * (h / dist);
  final p1 = m + n, p2 = m - n;
  return p1.distance > p2.distance ? p1 : p2;
}

/// One piece of the mark. Piece 0 is the top ring; piece k is piece 0 turned
/// k quarter turns clockwise.
class _Piece {
  _Piece(int k)
    : a = k * math.pi / 2,
      c = _turn(_c0, k * math.pi / 2),
      n = _turn(_n0, k * math.pi / 2),
      i = _turn(const Offset(1, -1), k * math.pi / 2),
      t = _turn(const Offset(1, 1), k * math.pi / 2),
      f = _turn(const Offset(3, 1), k * math.pi / 2),
      edgeIn = _turn(_c0 + Offset.fromDirection(_axis, _rIn), k * math.pi / 2),
      edgeOut = _turn(
        _c0 + Offset.fromDirection(_axis, _rOut),
        k * math.pi / 2,
      ),
      cut = _turn(_cutOut, k * math.pi / 2);

  /// This piece's turn, radians.
  final double a;

  /// Ring centre, and the centre of the ring it passes under.
  final Offset c, n;

  /// Arrowhead: inner corner, tip and barb. The tip is the next piece's
  /// inner corner.
  final Offset i, t, f;

  /// Band edges where they meet the arrowhead, and the outer edge's cut end.
  final Offset edgeIn, edgeOut, cut;

  // Piece 0's ring centre and the ring over its cut end.
  static const _c0 = Offset(0, -_ring), _n0 = Offset(-_ring, 0);
  static final _cutOut = _meet(_c0, _rOut, _n0, _rGap);
  static final _cutIn = _meet(_c0, _rIn, _n0, _rGap);

  /// Angles of the cut ends: around the piece's own ring (a*) and around the
  /// ring over it (b*). Add [a] for the piece's turn.
  static final aOut = (_cutOut - _c0).direction;
  static final aIn = (_cutIn - _c0).direction;
  static final bOut = (_cutOut - _n0).direction;
  static final bIn = (_cutIn - _n0).direction;
}

/// Writes mark units into a [Path]: turned by [tilt], then placed at
/// [origin], [unit] px per unit.
class _Pen {
  _Pen(this.origin, this.unit, this.tilt);

  final Offset origin;
  final double unit, tilt;
  final path = Path();

  Offset _px(Offset p) => origin + _turn(p, tilt) * unit;

  void moveTo(Offset p) {
    final q = _px(p);
    path.moveTo(q.dx, q.dy);
  }

  void lineTo(Offset p) {
    final q = _px(p);
    path.lineTo(q.dx, q.dy);
  }

  /// Arc round [c] of radius [r]; positive [sweep] runs clockwise.
  void arc(Offset c, double r, double from, double sweep) => path.arcTo(
    Rect.fromCircle(center: _px(c), radius: r * unit),
    from + tilt,
    sweep,
    false,
  );
}

/// The thread and the knot, laid out for one header size.
class _Thread {
  _Thread(this.size, this.underlap) {
    // The thread runs midway through the 24px under the pills.
    lineY = size.height - underlap - 12;
    unit = size.width * _knotWidth / (2 * _extent);
    final pieces = [for (var k = 0; k < 4; k++) _Piece(k)];

    // The thread joins and leaves at the knot's lowest point, heading right:
    // the bottom of whichever ring hangs lowest after the tilt. That ring's
    // outward side is within 45° of straight down, so the point is always on
    // its drawn rim.
    var s = 0;
    for (var k = 1; k < 4; k++) {
      if (_turn(pieces[k].c, _tilt).dy > _turn(pieces[s].c, _tilt).dy) s = k;
    }
    final b = pieces[s];
    final hang = _turn(b.c, _tilt);
    center = Offset(size.width * _knotX, lineY - (hang.dy + _rOut) * unit);
    join = Offset(center.dx + hang.dx * unit, lineY);
    // Piece angle that points straight down on screen, in (-π, π].
    final down = math.pi / 2 - b.a - _tilt;
    final low = math.atan2(math.sin(down), math.cos(down));

    final r = _extent * unit;
    strong = center + Offset(-0.55 * r, 0.8 * r);
    faint = center + Offset(0.55 * r, -0.8 * r);

    // Filled knot.
    final fill = _Pen(center, unit, _tilt);
    for (final p in pieces) {
      fill
        ..moveTo(p.cut)
        ..arc(p.c, _rOut, _Piece.aOut + p.a, _axis - _Piece.aOut)
        ..lineTo(p.f)
        ..lineTo(p.t)
        ..lineTo(p.i)
        ..lineTo(p.edgeIn)
        ..arc(p.c, _rIn, _axis + p.a, _Piece.aIn - _axis)
        ..arc(p.n, _rGap, _Piece.bIn + p.a, _Piece.bOut - _Piece.bIn);
      fill.path.close();
    }
    knot = fill.path;

    // The circuit: every edge of the outline once, in one stroke. The pieces
    // touch at the square's corners, so the thread hops between them there.
    final pen = _Pen(center, unit, _tilt)
      ..moveTo(b.c + Offset.fromDirection(low + b.a, _rOut))
      // Along the hanging ring's rim to its cut, back round its inner edge.
      ..arc(b.c, _rOut, low + b.a, _Piece.aOut - low)
      ..arc(b.n, _rGap, _Piece.bOut + b.a, _Piece.bIn - _Piece.bOut)
      ..arc(b.c, _rIn, _Piece.aIn + b.a, _axis - _Piece.aIn)
      ..lineTo(b.i);
    // Once round the centre square, against the clock.
    for (final k in [s + 3, s + 2, s + 1, s]) {
      pen.lineTo(pieces[k % 4].i);
    }
    // The other three pieces, tip first.
    for (final k in [s + 3, s + 2, s + 1]) {
      final p = pieces[k % 4];
      pen
        ..lineTo(p.f)
        ..lineTo(p.edgeOut)
        ..arc(p.c, _rOut, _axis + p.a, _Piece.aOut - _axis)
        ..arc(p.n, _rGap, _Piece.bOut + p.a, _Piece.bIn - _Piece.bOut)
        ..arc(p.c, _rIn, _Piece.aIn + p.a, _axis - _Piece.aIn)
        ..lineTo(p.i);
    }
    // Back to the hanging ring's tip and round its rim to the start.
    pen
      ..lineTo(b.f)
      ..lineTo(b.edgeOut)
      ..arc(b.c, _rOut, _axis + b.a, low - _axis);
    circuit = pen.path.computeMetrics().single;

    leadIn =
        (Path()
              ..moveTo(-8, lineY)
              ..lineTo(join.dx, lineY))
            .computeMetrics()
            .single;
    leadOut =
        (Path()
              ..moveTo(join.dx, lineY)
              ..lineTo(size.width + 8, lineY))
            .computeMetrics()
            .single;

    finished = _Frame(
      tail: leadIn.length,
      head: leadIn.length + circuit.length,
      fill: 1,
      turn: 0,
      spark: 0,
    );
  }

  final Size size;
  final double underlap;

  late final double lineY, unit;

  /// Knot centre, and where the thread joins it.
  late final Offset center, join;

  /// Ends of the dissolve: the knot's strong lower left, faint upper right.
  late final Offset strong, faint;

  late final Path knot;
  late final ui.PathMetric leadIn, circuit, leadOut;

  /// The knot fully tied and filled, for reduce-motion.
  late final _Frame finished;
}
