import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Header background, v3: v2 with motion taken from Alex Gorbunov's logo
/// animations (design4users.com/animated-logo-design).
///
/// What it borrows from them:
/// - whip and settle: strokes leave fast and slow right down into place
///   (cubic ease-out), instead of v2's even draw;
/// - stagger: the four pieces start one after another, round the knot
///   clockwise from where the line arrives, rather than all at once;
/// - fill after the outline, as the reference's shapes gain their colour
///   once the strokes have formed them;
/// - the exit: the knot shrinks away as its strokes unwind. Nothing leaves
///   to the right: the knot simply goes, and the line comes in again from
///   the left.
///
/// The reference's bounces (a pop as the shape locks, overshoot on turns, a
/// swell before leaving) are left out: the knot never overshoots. Nor does
/// it turn: once formed, it holds still until it goes.
///
/// The line still runs in from the left and hands over to the strokes at
/// the same speed, as in v2. A copy of header_logo_v1_fast.dart (v2), which
/// stays as it is. With the system "reduce motion" setting on, the finished
/// knot sits still.
class HeaderLogoV3 extends StatefulWidget {
  const HeaderLogoV3({super.key, this.underlap = 0});

  /// How far this background runs under the content below it. The thread
  /// stays above that edge.
  final double underlap;

  @override
  State<HeaderLogoV3> createState() => _HeaderLogoV3State();
}

class _HeaderLogoV3State extends State<HeaderLogoV3>
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
  static const loop = 9.6;

  // In: the head runs in from the left and reaches the knot. The tail
  // follows, drawing the lead-in back into the knot.
  static const inEnd = 1.8;
  static const tailStart = 1.0, tailEnd = 2.7;

  // Each piece whips round its outline in [draw], starting [stagger] after
  // the one before it: bottom (where the line arrives), left, top, right.
  static const draw = 2.8, stagger = 0.08;
  static const order = [2, 3, 0, 1];

  // The knot fills once its outline has formed, then holds still.
  static const fillStart = 3.2, fillEnd = 4.3;

  // Out: the knot shrinks as its strokes unwind. The rest of the loop is
  // empty.
  static const outStart = 7.6, eraseEnd = 8.6;
  static const unfillEnd = 8.1;
}

/// How small the knot gets as it goes.
const _gone = 0.88;

/// The head's run in along the lead-in, from rest, arriving at the speed the
/// strokes leave at. The strokes ease out on a cubic, so they leave at three
/// times their average pace; the lead-in is a cubic too, ending at that
/// speed (its speed is a parabola: a + (b − a)·u + (6m − 3a − 3b)·u(1 − u)).
class _Run {
  _Run(this.lead, this.stroke) {
    const t1 = _Beat.inEnd;
    final m1 = lead / t1;
    // Never faster than the lead-in can reach without running backwards.
    split = math.min(3 * stroke / _Beat.draw, 2.9 * m1);
    _k1 = 6 * m1 - 3 * split;
  }

  /// Lengths of the lead-in and of each stroke (half a piece's outline).
  final double lead, stroke;

  /// Speed where the line splits, px/s.
  late final double split;
  late final double _k1;

  /// Distance along the lead-in after [u] of its time.
  double inAt(double u) =>
      _Beat.inEnd * (split * u * u / 2 + _k1 * (u * u / 2 - u * u * u / 3));
}

/// One moment of the loop.
class _Frame {
  const _Frame({
    required this.inTail,
    required this.inHead,
    required this.draw,
    required this.erase,
    required this.fill,
    required this.scale,
    required this.spark,
  });

  /// Visible stretch of the lead-in, as distances along it.
  final double inTail, inHead;

  /// How far each piece's strokes have drawn round it (by piece index), and
  /// how far all have been undone, 0–1.
  final List<double> draw;
  final double erase;

  /// Knot fill, 0–1.
  final double fill;

  /// Knot size, about where the thread joins it.
  final double scale;

  /// Glow on the moving heads, 0–1.
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

    /// Sizes the knot about the join.
    void place() {
      final j = th!.join;
      canvas
        ..translate(j.dx, j.dy)
        ..scale(f.scale)
        ..translate(-j.dx, -j.dy);
    }

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

    if (f.fill > 0) {
      canvas.save();
      place();
      // Lit from the top-left.
      canvas.drawPath(
        th.knot,
        Paint()
          ..shader = ui.Gradient.linear(
            c - Offset(radius, radius),
            c + Offset(radius, radius),
            [
              T.yellow.withValues(alpha: 0.22 * f.fill),
              T.yellow.withValues(alpha: 0.06 * f.fill),
            ],
          ),
      );
      canvas.restore();
    }

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

    final lin = th.leadIn.length;
    final y = th.lineY;

    // Lead-in, fading toward its tail like a comet.
    if (f.inTail < lin && f.inHead > f.inTail) {
      final end = math.min(f.inHead, lin);
      final x0 = th.leadIn.getTangentForOffset(f.inTail)!.position.dx;
      final x1 = th.leadIn.getTangentForOffset(end)!.position.dx;
      canvas.drawPath(
        th.leadIn.extractPath(f.inTail, end),
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

    // The knot: every piece's outline from its start, both ways round; all
    // undone from the same starts. Heads are collected for the sparks.
    final heads = <Offset>[];
    canvas.save();
    place();
    for (var k = 0; k < 4; k++) {
      final loop = th.loops[k];
      final half = loop.length / 2;
      if (f.erase > 0) {
        final a = half * f.erase;
        if (a < half) {
          canvas.drawPath(loop.extractPath(a, loop.length - a), line);
        }
      } else if (f.draw[k] > 0) {
        final d = half * f.draw[k];
        canvas
          ..drawPath(loop.extractPath(0, d), line)
          ..drawPath(loop.extractPath(loop.length - d, loop.length), line);
        if (f.draw[k] < 1) {
          heads
            ..add(loop.getTangentForOffset(d)!.position)
            ..add(loop.getTangentForOffset(loop.length - d)!.position);
        }
      }
    }
    canvas.restore();

    canvas.restore();

    // A spark on each moving head: the lead-in's, then the strokes'.
    if (f.spark > 0) {
      canvas.save();
      if (heads.isNotEmpty) place();
      final points = heads.isNotEmpty
          ? heads
          : [
              if (f.inHead > f.inTail)
                th.leadIn
                    .getTangentForOffset(math.min(f.inHead, lin))!
                    .position,
            ];
      for (final p in points) {
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
      canvas.restore();
    }
  }

  static _Frame _frameAt(double s, _Thread th) {
    double at(double from, double to) =>
        ((s - from) / (to - from)).clamp(0.0, 1.0);
    double sine(double from, double to) =>
        Curves.easeInOutSine.transform(at(from, to));

    final lin = th.leadIn.length;
    final lastEnd = _Beat.inEnd + 3 * _Beat.stagger + _Beat.draw;

    if (s < _Beat.outStart) {
      final draw = List<double>.filled(4, 0);
      for (var i = 0; i < 4; i++) {
        final start = _Beat.inEnd + i * _Beat.stagger;
        draw[_Beat.order[i]] = Curves.easeOutCubic.transform(
          at(start, start + _Beat.draw),
        );
      }
      return _Frame(
        inTail: lin * sine(_Beat.tailStart, _Beat.tailEnd),
        inHead: th.run.inAt(at(0, _Beat.inEnd)).clamp(0.0, lin),
        draw: draw,
        erase: 0,
        fill: sine(_Beat.fillStart, _Beat.fillEnd),
        scale: 1,
        spark: sine(0, 0.3) * (1 - sine(lastEnd - 0.9, lastEnd - 0.3)),
      );
    }
    final going = at(_Beat.outStart, _Beat.eraseEnd);
    return _Frame(
      inTail: lin,
      inHead: lin,
      draw: const [1, 1, 1, 1],
      erase: Curves.easeInCubic.transform(going),
      fill: 1 - sine(_Beat.outStart, _Beat.unfillEnd),
      scale: 1 + (_gone - 1) * Curves.easeInCubic.transform(going),
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

    // Each piece's outline as one closed stroke, from the outermost point of
    // its rim on round to the head, back along the inner edge and the cut,
    // and round the rim again. The bottom piece's start is where the
    // lead-in arrives; the others start at the same point a quarter turn on.
    const low = -math.pi / 2; // piece angle of that point
    for (final p in pieces) {
      final pen = _Pen(center, unit)
        ..moveTo(p.c + Offset.fromDirection(low + p.a, _rOut))
        ..arc(p.c, _rOut, low + p.a, _axis - low)
        ..lineTo(p.f)
        ..lineTo(p.t)
        ..lineTo(p.i)
        ..lineTo(p.edgeIn)
        ..arc(p.c, _rIn, _axis + p.a, _Piece.aIn - _axis)
        ..arc(p.n, _rGap, _Piece.bIn + p.a, _Piece.bOut - _Piece.bIn)
        ..arc(p.c, _rOut, _Piece.aOut + p.a, low - _Piece.aOut);
      loops.add(pen.path.computeMetrics().single);
    }

    leadIn =
        (Path()
              ..moveTo(-8, lineY)
              ..lineTo(center.dx, lineY))
            .computeMetrics()
            .single;

    run = _Run(leadIn.length, loops.first.length / 2);
    join = Offset(center.dx, lineY);

    finished = _Frame(
      inTail: leadIn.length,
      inHead: leadIn.length,
      draw: const [1, 1, 1, 1],
      erase: 0,
      fill: 1,
      scale: 1,
      spark: 0,
    );
  }

  final Size size;
  final double underlap;

  late final double lineY, unit;
  late final Offset center;
  late final Path knot;
  late final ui.PathMetric leadIn;

  /// The four pieces' outlines, each a closed stroke.
  final loops = <ui.PathMetric>[];

  /// How the head and the strokes move.
  late final _Run run;

  /// Where the lead-in meets the knot: the bottom ring's lowest point. The
  /// knot shrinks about it as it goes, so it leaves where the thread joined.
  late final Offset join;

  /// The knot fully tied and filled, for reduce-motion.
  late final _Frame finished;
}
