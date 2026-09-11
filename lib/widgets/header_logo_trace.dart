import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Header background: a hairline of brand yellow runs in from the left along
/// the header's lower edge, ties itself into the TDB knot, gives the knot a
/// quarter turn, then unties and slips away to the right. Loops every 10 s.
///
/// The thread is one path: the lead-in, a single unbroken circuit over the
/// mark's outline, and the lead-out. So the line that arrives is the line
/// that draws the mark and the line that leaves. With the system "reduce
/// motion" setting on, the finished knot sits still.
class HeaderLogoTrace extends StatefulWidget {
  const HeaderLogoTrace({super.key, this.underlap = 0});

  /// How far this background runs under the content below it. The thread
  /// stays above that edge.
  final double underlap;

  @override
  State<HeaderLogoTrace> createState() => _HeaderLogoTraceState();
}

class _HeaderLogoTraceState extends State<HeaderLogoTrace>
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

/// Beats of the loop, in seconds.
class _Beat {
  static const loop = 10.0;

  // Tie: the head runs in and round the whole circuit. The tail follows only
  // as far as the knot, drawing the lead-in back into it.
  static const tieEnd = 3.6;
  static const tailStart = 0.8, tailEnd = 2.6;
  static const sparkIn = 0.25, sparkOutStart = 3.2;

  // The knot fills as the circuit closes, then turns a quarter.
  static const fillStart = 2.8, fillEnd = 4.2;
  static const turnStart = 4.2, turnEnd = 5.6;

  // Untie: the head pulls out to the right and the tail unwinds the circuit
  // after it. The rest of the loop is empty.
  static const untieStart = 6.1, pullEnd = 7.1, unfillEnd = 7.2;
  static const untieEnd = 8.9;
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

  /// Knot fill, 0–1.
  final double fill;

  /// Knot rotation, radians clockwise.
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
    final radius = _extent * th.unit;

    // A soft light behind the knot once it has filled.
    if (f.fill > 0) {
      canvas.drawCircle(
        c,
        radius * 1.5,
        Paint()
          ..shader = ui.Gradient.radial(c, radius * 1.5, [
            T.yellow.withValues(alpha: 0.07 * f.fill),
            T.yellow.withValues(alpha: 0),
          ]),
      );
    }

    canvas.save();
    if (f.turn != 0) {
      canvas
        ..translate(c.dx, c.dy)
        ..rotate(f.turn)
        ..translate(-c.dx, -c.dy);
    }
    if (f.fill > 0) {
      // Lit from the top-left; the light stays put while the knot turns.
      Offset fixed(Offset p) => c + _turn(p - c, -f.turn);
      canvas.drawPath(
        th.knot,
        Paint()
          ..shader = ui.Gradient.linear(
            fixed(c - Offset(radius, radius)),
            fixed(c + Offset(radius, radius)),
            [
              T.yellow.withValues(alpha: 0.22 * f.fill),
              T.yellow.withValues(alpha: 0.06 * f.fill),
            ],
          ),
      );
    }
    canvas.restore();

    // The thread is stroked opaque into a layer and faded as a whole, so the
    // spots where it crosses itself don't double up.
    canvas.saveLayer(
      bounds,
      Paint()..color = Color.fromRGBO(0, 0, 0, 0.9 - 0.4 * f.fill),
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

    // The circuit over the knot.
    final a = math.max(f.tail - lin, 0.0), b = math.min(f.head - lin, knot);
    if (b > a) {
      canvas.save();
      if (f.turn != 0) {
        canvas
          ..translate(c.dx, c.dy)
          ..rotate(f.turn)
          ..translate(-c.dx, -c.dy);
      }
      canvas.drawPath(th.circuit.extractPath(a, b), line);
      canvas.restore();
    }

    // Lead-out, dissolving toward the right edge.
    final oa = math.max(f.tail - lin - knot, 0.0), ob = f.head - lin - knot;
    if (ob > oa) {
      canvas.drawPath(
        th.leadOut.extractPath(oa, ob),
        Paint.from(line)
          ..shader = ui.Gradient.linear(
            Offset(c.dx, y),
            Offset(size.width, y),
            [T.yellow, T.yellow.withValues(alpha: 0)],
            [0.1, 1],
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

/// Writes mark units into a [Path] at [origin], [unit] px per unit.
class _Pen {
  _Pen(this.origin, this.unit);

  final Offset origin;
  final double unit;
  final path = Path();

  Offset _px(Offset p) => origin + p * unit;

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
    from,
    sweep,
    false,
  );
}

/// The thread and the knot, laid out for one header size.
class _Thread {
  _Thread(this.size, this.underlap) {
    // The thread runs midway through the 24px under the pills; the knot
    // sits on it at the right, inset like the bell button above.
    lineY = size.height - underlap - 12;
    final width = (size.width * 0.34).clamp(128.0, 168.0);
    unit = width / (2 * _extent);
    center = Offset(size.width - 20 - width / 2, lineY - width / 2);

    final pieces = [for (var k = 0; k < 4; k++) _Piece(k)];

    // Filled knot.
    final fill = _Pen(center, unit);
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
    // It joins and leaves at the bottom ring's lowest point, heading right.
    const s = 2;
    final b = pieces[s];
    const low = -math.pi / 2; // piece angle of that point
    final pen = _Pen(center, unit)
      ..moveTo(b.c + Offset.fromDirection(low + b.a, _rOut))
      // Up the bottom ring's rim to its cut, back round its inner edge.
      ..arc(b.c, _rOut, low + b.a, _Piece.aOut - low)
      ..arc(b.n, _rGap, _Piece.bOut + b.a, _Piece.bIn - _Piece.bOut)
      ..arc(b.c, _rIn, _Piece.aIn + b.a, _axis - _Piece.aIn)
      ..lineTo(b.i);
    // Once round the centre square, against the clock.
    for (final k in const [s + 3, s + 2, s + 1, s]) {
      pen.lineTo(pieces[k % 4].i);
    }
    // The other three pieces, tip first.
    for (final k in const [s + 3, s + 2, s + 1]) {
      final p = pieces[k % 4];
      pen
        ..lineTo(p.f)
        ..lineTo(p.edgeOut)
        ..arc(p.c, _rOut, _axis + p.a, _Piece.aOut - _axis)
        ..arc(p.n, _rGap, _Piece.bOut + p.a, _Piece.bIn - _Piece.bOut)
        ..arc(p.c, _rIn, _Piece.aIn + p.a, _axis - _Piece.aIn)
        ..lineTo(p.i);
    }
    // Back to the bottom ring's tip and round its rim to the start.
    pen
      ..lineTo(b.f)
      ..lineTo(b.edgeOut)
      ..arc(b.c, _rOut, _axis + b.a, low - _axis);
    circuit = pen.path.computeMetrics().single;

    leadIn =
        (Path()
              ..moveTo(-8, lineY)
              ..lineTo(center.dx, lineY))
            .computeMetrics()
            .single;
    leadOut =
        (Path()
              ..moveTo(center.dx, lineY)
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
  late final Offset center;
  late final Path knot;
  late final ui.PathMetric leadIn, circuit, leadOut;

  /// The knot fully tied and filled, for reduce-motion.
  late final _Frame finished;
}
