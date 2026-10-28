import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Header backgrounds from one engine: a yellow hairline runs across the
/// header, ties the TDB knot (or a few of them) in one unbroken stroke, holds
/// while the knots fill and turn, then unties and slips away off the far edge.
///
/// v1 (header_logo_trace.dart) and v2 (header_logo_trace_v2.dart) are the
/// hand-tuned originals and stay as they are. The variants below are the same
/// idea under a few knobs — see [logoVariants].

/// One knot on the thread.
class KnotSpec {
  const KnotSpec({required this.x, required this.width, this.tilt = 0});

  /// Centre across the header, and width, as fractions of the header's width.
  final double x, width;

  /// Lean in degrees, negative to the left. The mark repeats every quarter
  /// turn, so 75 and -15 look the same.
  final double tilt;
}

/// A header background: where the thread runs, what it ties along the way,
/// and how the knots behave once tied. [HeaderLogoVariant] draws it.
class LogoVariant {
  const LogoVariant({
    required this.name,
    required this.knots,
    this.angle = 0,
    this.anchor = 12,
    this.fill = 0.16,
    this.dissolve = 0.35,
    this.lineWidth = 1.25,
    this.drawing = 0.85,
    this.settled = 0.45,
    this.spin = 0.25,
    this.glint = false,
    this.seconds = 11,
  });

  /// Shown when this variant is switched on.
  final String name;

  final List<KnotSpec> knots;

  /// Thread angle in degrees; negative rises to the right.
  final double angle;

  /// Where the thread crosses the middle of the header, in px above the
  /// sheet's edge.
  final double anchor;

  /// Peak fill of a tied knot; 0 leaves it an outline.
  final double fill;

  /// How far a tied knot fades away from the thread, 0–1.
  final double dissolve;

  final double lineWidth;

  /// Thread alpha while it draws, and once the knot is tied.
  final double drawing, settled;

  /// Turns a tied knot makes. The mark repeats every quarter turn, so only
  /// multiples of 0.25 land back on themselves.
  final double spin;

  /// Sweeps a bright glint round the outline before untying.
  final bool glint;

  /// One loop.
  final double seconds;
}

/// The variants offered next to v1 and v2, in cycling order.
const logoVariants = <LogoVariant>[
  LogoVariant(
    name: 'Лого v3 — гурван зангилаа',
    // Big enough to stand clear of the pills the thread runs under.
    knots: [
      KnotSpec(x: 0.18, width: 0.27),
      KnotSpec(x: 0.50, width: 0.27),
      KnotSpec(x: 0.82, width: 0.27),
    ],
    fill: 0.11,
    dissolve: 0.3,
    settled: 0.38,
    seconds: 13,
  ),
  LogoVariant(
    name: 'Лого v4 — төвд, зөвхөн контур',
    knots: [KnotSpec(x: 0.5, width: 0.46)],
    fill: 0,
    dissolve: 0,
    lineWidth: 1,
    drawing: 0.7,
    settled: 0.34,
    spin: 0,
    seconds: 14,
  ),
  LogoVariant(
    name: 'Лого v5 — диагональ, налуу',
    knots: [KnotSpec(x: 0.63, width: 0.40, tilt: 30)],
    angle: -18,
    anchor: 70,
    fill: 0.18,
    dissolve: 0.5,
    settled: 0.46,
    seconds: 11,
  ),
  LogoVariant(
    name: 'Лого v6 — том, удаан эргэлдэнэ',
    knots: [KnotSpec(x: 0.74, width: 0.62)],
    fill: 0.2,
    dissolve: 0.55,
    settled: 0.4,
    spin: 0.5,
    seconds: 13,
  ),
  LogoVariant(
    name: 'Лого v7 — гялбаа тусна',
    knots: [KnotSpec(x: 0.74, width: 0.42)],
    fill: 0.16,
    dissolve: 0.35,
    settled: 0.45,
    glint: true,
    seconds: 12,
  ),
];

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class HeaderLogoVariant extends StatefulWidget {
  const HeaderLogoVariant({
    super.key,
    required this.variant,
    this.underlap = 0,
  });

  final LogoVariant variant;

  /// How far this background runs under the content below it. The thread
  /// stays above that edge.
  final double underlap;

  @override
  State<HeaderLogoVariant> createState() => _HeaderLogoVariantState();
}

class _HeaderLogoVariantState extends State<HeaderLogoVariant>
    with SingleTickerProviderStateMixin {
  final _cache = _Cache();
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: _loop,
  );

  Duration get _loop =>
      Duration(milliseconds: (widget.variant.seconds * 1000).round());

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
  void didUpdateWidget(covariant HeaderLogoVariant old) {
    super.didUpdateWidget(old);
    // Only if this widget is swapped to another variant without a new key.
    if (old.variant != widget.variant || old.underlap != widget.underlap) {
      _cache.clear();
      _clock.duration = _loop;
      if (_clock.isAnimating) _clock.repeat();
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
        painter: _VariantPainter(
          _clock,
          _cache,
          widget.variant,
          widget.underlap,
          MediaQuery.disableAnimationsOf(context),
        ),
        size: Size.infinite,
      ),
    );
  }
}

/// Beats of the loop, as fractions of it.
class _Beat {
  // Tie: the head runs in and round every knot. The tail follows only as far
  // as the first knot, drawing the lead-in back into it.
  static const tieEnd = 0.38;
  static const tailStart = 0.05, tailEnd = 0.20;
  static const sparkIn = 0.02, sparkOut = 0.34;

  // The knots fill and dissolve as the last circuit closes, then turn.
  static const fillStart = 0.30, fillEnd = 0.44;
  static const turnStart = 0.44, turnEnd = 0.60;
  static const glintStart = 0.60, glintEnd = 0.72;

  // Untie: the head pulls out past the far edge and the tail unwinds after
  // it. The rest of the loop is empty.
  static const untieStart = 0.74, unfillEnd = 0.84, pullEnd = 0.86;
  static const untieEnd = 0.93;
}

/// One moment of the loop.
class _Frame {
  const _Frame({
    required this.tail,
    required this.head,
    required this.fill,
    required this.turn,
    required this.spark,
    required this.glint,
  });

  /// Visible stretch of the thread, as distances along it.
  final double tail, head;

  /// Knot fill and dissolve, 0–1.
  final double fill;

  /// Knot rotation on top of its lean, radians clockwise.
  final double turn;

  /// Glow on the moving head, 0–1.
  final double spark;

  /// How far the glint has swept a knot's outline, or -1 for none.
  final double glint;
}

class _VariantPainter extends CustomPainter {
  _VariantPainter(
    this.clock,
    this.cache,
    this.variant,
    this.underlap,
    this.still,
  ) : super(repaint: clock);

  final Animation<double> clock;
  final _Cache cache;
  final LogoVariant variant;
  final double underlap;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = T.inkDeep);
    if (size.isEmpty) return;

    final g = cache.of(size, variant, underlap);
    final f = still ? g.finished : _frameAt(clock.value, g);

    // Tied knots, filled and fading away from the thread.
    if (variant.fill > 0 && f.fill > 0) {
      final peak = variant.fill * f.fill;
      for (final knot in g.knots) {
        canvas.save();
        _spin(canvas, knot.centre, f.turn);
        canvas.drawPath(
          knot.fill,
          Paint()
            ..shader = knot.fade(
              f.turn,
              T.yellow.withValues(alpha: peak),
              T.yellow.withValues(alpha: peak * (1 - variant.dissolve)),
            ),
        );
        canvas.restore();
      }
    }

    // The thread is stroked opaque into a layer and faded as a whole, so the
    // spots where it crosses itself don't double up.
    canvas.saveLayer(
      bounds,
      Paint()
        ..color = Color.fromRGBO(
          0,
          0,
          0,
          ui.lerpDouble(variant.drawing, variant.settled, f.fill)!,
        ),
    );
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = variant.lineWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = T.yellow;
    final dissolve = variant.dissolve * (0.55 + 0.45 * f.fill);
    Offset? headAt;

    for (final leg in g.legs) {
      final a = math.max(f.tail - leg.start, 0.0);
      final b = math.min(f.head - leg.start, leg.metric.length);
      if (b <= a) continue;
      if (f.head <= leg.start + leg.metric.length) {
        headAt = leg.metric.getTangentForOffset(b)?.position;
      }
      final piece = leg.metric.extractPath(a, b);

      final knot = leg.knot;
      if (knot != null) {
        canvas.save();
        _spin(canvas, knot.centre, f.turn);
        canvas.drawPath(
          piece,
          Paint.from(line)
            ..shader = knot.fade(
              f.turn,
              T.yellow,
              T.yellow.withValues(alpha: 1 - dissolve),
            ),
        );
        canvas.restore();
        continue;
      }

      // A straight run. The lead-in trails off behind the head like a comet,
      // the lead-out dissolves toward the edge, links between knots are plain.
      final paint = Paint.from(line);
      if (leg.run == _Run.lead) {
        final from = leg.metric.getTangentForOffset(a)!.position;
        final to = leg.metric.getTangentForOffset(b)!.position;
        paint.shader = (to - from).distance < 2
            ? null
            : ui.Gradient.linear(
                from,
                to,
                [T.yellow.withValues(alpha: 0), T.yellow],
                [0, 0.8],
              );
      } else if (leg.run == _Run.tail) {
        paint.shader = ui.Gradient.linear(
          leg.metric.getTangentForOffset(0)!.position,
          leg.metric.getTangentForOffset(leg.metric.length)!.position,
          [T.yellow, T.yellow.withValues(alpha: 0)],
          [0.3, 1],
        );
      }
      canvas.drawPath(piece, paint);
    }
    canvas.restore();

    // A glint sweeping the tied outline, brighter than the settled thread.
    if (f.glint >= 0) {
      final bright = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = variant.lineWidth + 0.4
        ..strokeCap = StrokeCap.round
        ..color = Color.lerp(
          T.yellow,
          Colors.white,
          0.3,
        )!.withValues(alpha: 0.7);
      for (final knot in g.knots) {
        final len = knot.circuit.length;
        final end = f.glint * len;
        final from = math.max(end - len * 0.12, 0.0);
        if (end > from) {
          canvas.drawPath(knot.circuit.extractPath(from, end), bright);
        }
      }
    }

    // A spark on the head while it draws.
    if (f.spark > 0 && headAt != null) {
      final p = headAt;
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

  /// Turns the canvas round a knot's centre.
  void _spin(Canvas canvas, Offset centre, double turn) {
    if (turn == 0) return;
    canvas
      ..translate(centre.dx, centre.dy)
      ..rotate(turn)
      ..translate(-centre.dx, -centre.dy);
  }

  _Frame _frameAt(double t, _Geometry g) {
    double at(double from, double to) =>
        ((t - from) / (to - from)).clamp(0.0, 1.0);

    final lin = g.legs.first.metric.length;

    if (t < _Beat.untieStart) {
      return _Frame(
        tail:
            lin *
            Curves.easeInOutCubic.transform(at(_Beat.tailStart, _Beat.tailEnd)),
        head: g.tied * Curves.easeInOutSine.transform(at(0, _Beat.tieEnd)),
        fill: Curves.easeOutCubic.transform(at(_Beat.fillStart, _Beat.fillEnd)),
        // Past the turn the knot matches itself again, so it snaps back to 0.
        turn: t < _Beat.turnEnd
            ? variant.spin *
                  2 *
                  math.pi *
                  Curves.easeInOutCubic.transform(
                    at(_Beat.turnStart, _Beat.turnEnd),
                  )
            : 0,
        spark: at(0, _Beat.sparkIn) * (1 - at(_Beat.sparkOut, _Beat.tieEnd)),
        glint: variant.glint && t >= _Beat.glintStart && t <= _Beat.glintEnd
            ? Curves.easeInOutSine.transform(
                at(_Beat.glintStart, _Beat.glintEnd),
              )
            : -1,
      );
    }
    return _Frame(
      tail:
          lin +
          (g.total - lin) *
              Curves.easeInOutSine.transform(
                at(_Beat.untieStart, _Beat.untieEnd),
              ),
      head:
          g.tied +
          (g.total - g.tied) *
              Curves.easeInOutSine.transform(
                at(_Beat.untieStart, _Beat.pullEnd),
              ),
      fill:
          1 -
          Curves.easeInCubic.transform(at(_Beat.untieStart, _Beat.unfillEnd)),
      turn: 0,
      spark: 0,
      glint: -1,
    );
  }

  @override
  bool shouldRepaint(_VariantPainter old) =>
      old.still != still || old.variant != variant || old.underlap != underlap;
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

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

/// [a] folded into (-π, π].
double _wrap(double a) => math.atan2(math.sin(a), math.cos(a));

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

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

/// One knot, placed on the thread.
class _KnotGeom {
  _KnotGeom(KnotSpec spec, double width, Offset u, Offset n, this.join)
    : unit = width / (2 * _extent),
      tilt = spec.tilt * math.pi / 180 {
    final pieces = [for (var k = 0; k < 4; k++) _Piece(k)];

    // The thread touches the knot at the far rim of whichever ring leans
    // furthest across it. That ring's outward side is within 45° of the
    // thread's normal, so the touch always lands on its drawn rim.
    var s = 0;
    for (var k = 1; k < 4; k++) {
      if (_dot(_turn(pieces[k].c, tilt), n) >
          _dot(_turn(pieces[s].c, tilt), n)) {
        s = k;
      }
    }
    final b = pieces[s];
    centre = join - (_turn(b.c, tilt) + n * _rOut) * unit;
    // Piece angle that points across the thread, away from it.
    final low = _wrap(n.direction - b.a - tilt);

    final r = _extent * unit;
    final away = (n * 0.8 - u * 0.55) * r;
    strong = centre + away;
    faint = centre - away;

    final filled = _Pen(centre, unit, tilt);
    for (final p in pieces) {
      filled
        ..moveTo(p.cut)
        ..arc(p.c, _rOut, _Piece.aOut + p.a, _axis - _Piece.aOut)
        ..lineTo(p.f)
        ..lineTo(p.t)
        ..lineTo(p.i)
        ..lineTo(p.edgeIn)
        ..arc(p.c, _rIn, _axis + p.a, _Piece.aIn - _axis)
        ..arc(p.n, _rGap, _Piece.bIn + p.a, _Piece.bOut - _Piece.bIn);
      filled.path.close();
    }
    fill = filled.path;

    // The circuit: every edge of the outline once, in one stroke. The pieces
    // touch at the square's corners, so the thread hops between them there.
    final pen = _Pen(centre, unit, tilt)
      ..moveTo(b.c + Offset.fromDirection(low + b.a, _rOut))
      // Along the touching ring's rim to its cut, back round its inner edge.
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
    // Back to the touching ring's tip and round its rim to the start.
    pen
      ..lineTo(b.f)
      ..lineTo(b.edgeOut)
      ..arc(b.c, _rOut, _axis + b.a, low - _axis);
    circuit = pen.path.computeMetrics().single;
  }

  final double unit, tilt;

  /// Where the thread touches this knot.
  final Offset join;

  late final Offset centre;

  /// Ends of the fade: strong by the thread, faint on the far side.
  late final Offset strong, faint;

  late final Path fill;
  late final ui.PathMetric circuit;

  /// The fade, in the frame of a knot turned by [turn] — the ends are held in
  /// place so the light doesn't turn with the knot.
  ui.Gradient fade(double turn, Color from, Color to) {
    Offset held(Offset p) => centre + _turn(p - centre, -turn);
    return ui.Gradient.linear(held(strong), held(faint), [from, to]);
  }
}

/// What a straight stretch of thread is for.
enum _Run { lead, link, tail }

/// One stretch of the thread: a straight run, or the circuit round one knot.
class _Leg {
  _Leg.run(this.metric, this.run) : knot = null;
  _Leg.knot(_KnotGeom this.knot) : metric = knot.circuit, run = null;

  final ui.PathMetric metric;
  final _KnotGeom? knot;
  final _Run? run;

  /// Distance from the thread's start to this leg's start.
  late final double start;
}

/// The thread and its knots, laid out for one header size.
class _Geometry {
  _Geometry(this.size, this.variant, this.underlap) {
    final rad = variant.angle * math.pi / 180;
    final u = Offset(math.cos(rad), math.sin(rad));
    // A quarter turn clockwise from the thread: the side the knots hang from.
    final n = Offset(-u.dy, u.dx);
    final mid = Offset(size.width / 2, size.height - underlap - variant.anchor);
    double along(double x) => (x - mid.dx) / u.dx;

    final specs = [...variant.knots]..sort((a, b) => a.x.compareTo(b.x));
    for (final spec in specs) {
      final at = along(size.width * spec.x);
      knots.add(_KnotGeom(spec, size.width * spec.width, u, n, mid + u * at));
    }

    // Where the thread crosses the canvas edge before the first knot and
    // after the last, a little outside it.
    final (from, to) = _span(
      mid,
      u,
      along(size.width * specs.first.x),
      along(size.width * specs.last.x),
    );

    legs.add(_Leg.run(_straight(mid + u * from, knots.first.join), _Run.lead));
    for (var i = 0; i < knots.length; i++) {
      legs.add(_Leg.knot(knots[i]));
      if (i + 1 < knots.length) {
        legs.add(
          _Leg.run(_straight(knots[i].join, knots[i + 1].join), _Run.link),
        );
      }
    }
    legs.add(_Leg.run(_straight(knots.last.join, mid + u * to), _Run.tail));

    var at = 0.0;
    for (final leg in legs) {
      leg.start = at;
      at += leg.metric.length;
    }
    total = at;
    tied = total - legs.last.metric.length;
    finished = _Frame(
      tail: legs.first.metric.length,
      head: tied,
      fill: 1,
      turn: 0,
      spark: 0,
      glint: -1,
    );
  }

  final Size size;
  final LogoVariant variant;
  final double underlap;

  final knots = <_KnotGeom>[];
  final legs = <_Leg>[];

  /// The whole thread, and the part of it that is the knots plus their leads.
  late final double total, tied;

  /// Every knot tied and filled, for reduce-motion.
  late final _Frame finished;

  ui.PathMetric _straight(Offset a, Offset b) =>
      (Path()
            ..moveTo(a.dx, a.dy)
            ..lineTo(b.dx, b.dy))
          .computeMetrics()
          .single;

  /// How far along the thread the canvas edge sits, either side of the knots.
  (double, double) _span(Offset mid, Offset u, double first, double last) {
    const pad = 8.0;
    final crossings = <double>[];
    void cross(double target, double from, double dir) {
      if (dir.abs() > 1e-6) crossings.add((target - from) / dir);
    }

    cross(-pad, mid.dx, u.dx);
    cross(size.width + pad, mid.dx, u.dx);
    cross(-pad, mid.dy, u.dy);
    cross(size.height + pad, mid.dy, u.dy);
    final before = crossings.where((t) => t < first);
    final after = crossings.where((t) => t > last);
    return (
      before.isEmpty ? first - size.width : before.reduce(math.max),
      after.isEmpty ? last + size.width : after.reduce(math.min),
    );
  }
}

/// Holds the layout for as long as the size and variant hold still.
class _Cache {
  _Geometry? _geometry;

  void clear() => _geometry = null;

  _Geometry of(Size size, LogoVariant variant, double underlap) {
    var g = _geometry;
    if (g == null ||
        g.size != size ||
        g.variant != variant ||
        g.underlap != underlap) {
      g = _geometry = _Geometry(size, variant, underlap);
    }
    return g;
  }
}
