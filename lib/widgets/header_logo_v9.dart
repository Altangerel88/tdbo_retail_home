import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// v9: the mark's four arrows swirl in from the four sides and lock together.
///
/// The TDB mark is four identical arrows a quarter turn apart, each pointing
/// clockwise round the centre square. Here they start off the header, pushed
/// out from their places, and spiral in head first as one clockwise pinwheel,
/// each trailing a fading line. Their tips meet the square's corners with a
/// spark, the mark fills, and its turn winds down to rest upright where v8's
/// knot rests. Then the pinwheel spins up again, the arrows spiral back out,
/// still clockwise, and the loop starts over.
///
/// Self-contained: the mark's geometry is copied from header_logo_v8.dart,
/// which stays as it is.

/// The resting mark and its look, as v8 has them once tied.
class _Look {
  /// Centre across the header, and width, as fractions of the header's width.
  static const x = 0.74, width = 0.62;

  /// The mark's lowest edge, px above the sheet.
  static const anchor = 12.0;

  /// Peak fill, and how far the mark fades toward its upper right, 0–1.
  static const fill = 0.2, dissolve = 0.55;

  static const lineWidth = 1.25;

  /// Outline alpha while the arrows fly, and once the mark has formed.
  static const flying = 0.85, settled = 0.4;

  /// Share of the full fill an arrow carries in flight.
  static const flyingFill = 0.3;

  /// One loop.
  static const seconds = 16.0;
}

/// Beats of the loop, as fractions of it.
class _Beat {
  // In: the arrows close in until their tips meet, while the pinwheel's turn
  // runs on past the meeting and winds down to rest.
  static const meet = 0.38, rest = 0.60;

  // The mark fills as it forms; a spark lights each corner as a tip lands.
  static const fillStart = 0.35, fillEnd = 0.52;
  static const sparkStart = 0.33, sparkEnd = 0.50;

  // Out: the pinwheel spins up and the arrows part and spiral away. The
  // header stays empty until they come round again.
  static const outStart = 0.74, unfillEnd = 0.84, outEnd = 0.95;

  /// How far back in the loop a trail reaches.
  static const trail = 0.07;
}

/// Pinwheel turn, radians clockwise: where the arrows start, where the mark
/// rests (a quarter turn on, which looks the same as none), where they leave.
const _turnIn = -math.pi, _turnRest = math.pi / 2, _turnOut = 3 * math.pi / 2;

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class HeaderLogoV9 extends StatefulWidget {
  const HeaderLogoV9({super.key, this.underlap = 0});

  /// How far this background runs under the content below it. The mark
  /// rests above that edge.
  final double underlap;

  @override
  State<HeaderLogoV9> createState() => _HeaderLogoV9State();
}

class _HeaderLogoV9State extends State<HeaderLogoV9>
    with SingleTickerProviderStateMixin {
  final _cache = _Cache();
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_Look.seconds * 1000).round()),
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
  void didUpdateWidget(covariant HeaderLogoV9 old) {
    super.didUpdateWidget(old);
    if (old.underlap != widget.underlap) _cache.clear();
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
        painter: _SwirlPainter(
          _clock,
          _cache,
          widget.underlap,
          MediaQuery.disableAnimationsOf(context),
        ),
        size: Size.infinite,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Motion
// ---------------------------------------------------------------------------

/// Where the arrows are: how far each is pushed out from its place, px, and
/// how far the pinwheel has turned, radians clockwise.
typedef _Pose = ({double spread, double turn});

double _at(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

/// The arrows' path, a pure function of the loop so trails can look back
/// along it. [far] is a spread that puts every arrow off the header.
_Pose _poseAt(double t, double far) {
  if (t < _Beat.outStart) {
    return (
      // Fast from off the header, then a long soft landing.
      spread: far * (1 - Curves.easeOutCubic.transform(_at(t, 0, _Beat.meet))),
      // Slows all the way, but is still turning when the tips meet.
      turn:
          _turnIn +
          (_turnRest - _turnIn) *
              Curves.easeOutQuad.transform(_at(t, 0, _Beat.rest)),
    );
  }
  final going = _at(t, _Beat.outStart, _Beat.outEnd);
  return (
    // The turn picks up before the arrows part.
    spread: far * Curves.easeInCubic.transform(going),
    turn:
        _turnRest + (_turnOut - _turnRest) * Curves.easeInQuad.transform(going),
  );
}

/// What else the loop is doing at one moment, each 0–1.
class _Frame {
  const _Frame({
    required this.formed,
    required this.spark,
    required this.trail,
  });

  /// How far the arrows have become one mark: fill, outline alpha, dissolve.
  final double formed;

  /// Glow where the tips meet the square's corners.
  final double spark;

  /// Strength of the trails.
  final double trail;

  static const still = _Frame(formed: 1, spark: 0, trail: 0);
}

_Frame _frameAt(double t) {
  double ease(double from, double to) =>
      Curves.easeInOutSine.transform(_at(t, from, to));

  if (t < _Beat.outStart) {
    return _Frame(
      formed: ease(_Beat.fillStart, _Beat.fillEnd),
      spark:
          ease(_Beat.sparkStart, _Beat.meet) *
          (1 - ease(_Beat.meet, _Beat.sparkEnd)),
      // The pinwheel still turns after the meeting; its trails shouldn't
      // linger on the formed mark.
      trail: 1 - ease(_Beat.meet, _Beat.meet + 0.06),
    );
  }
  return _Frame(
    formed: 1 - ease(_Beat.outStart, _Beat.unfillEnd),
    spark: 0,
    trail: ease(_Beat.outStart, _Beat.outStart + 0.06),
  );
}

// ---------------------------------------------------------------------------
// Painting
// ---------------------------------------------------------------------------

class _SwirlPainter extends CustomPainter {
  _SwirlPainter(this.clock, this.cache, this.underlap, this.still)
    : super(repaint: clock);

  final Animation<double> clock;
  final _Cache cache;
  final double underlap;
  final bool still;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = T.inkDeep);
    if (size.isEmpty) return;

    final g = cache.of(size, underlap);
    final t = clock.value;
    final f = still ? _Frame.still : _frameAt(t);
    final pose = still ? (spread: 0.0, turn: 0.0) : _poseAt(t, g.far);

    final placed = [
      for (final a in g.arrows)
        a.outline.transform(_place(g.centre, pose.turn, a.out * pose.spread)),
    ];

    // Fill, fading away from the lower left like v8's knot. The fade stays
    // put on the header while the arrows move through it.
    final peak =
        _Look.fill * (_Look.flyingFill + (1 - _Look.flyingFill) * f.formed);
    final fill = Paint()
      ..shader = g.fade(
        T.yellow.withValues(alpha: peak),
        T.yellow.withValues(alpha: peak * (1 - _Look.dissolve)),
      );
    for (final p in placed) {
      canvas.drawPath(p, fill);
    }

    // Outlines and trails, stroked opaque into a layer faded as a whole. The
    // outline flares as the tips meet, then settles.
    final alpha =
        (ui.lerpDouble(_Look.flying, _Look.settled, f.formed)! + 0.2 * f.spark)
            .clamp(0.0, 1.0);
    canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    final dissolve = _Look.dissolve * (0.55 + 0.45 * f.formed);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _Look.lineWidth
      ..strokeJoin = StrokeJoin.round
      ..shader = g.fade(T.yellow, T.yellow.withValues(alpha: 1 - dissolve));
    for (final p in placed) {
      canvas.drawPath(p, line);
    }
    if (f.trail > 0) _trails(canvas, g, t, f.trail);
    canvas.restore();

    // A spark on each corner of the centre square as a tip lands on it.
    if (f.spark > 0) {
      for (final a in g.arrows) {
        final p = g.centre + _turn(a.tip + a.out * pose.spread, pose.turn);
        canvas
          ..drawCircle(
            p,
            11,
            Paint()
              ..shader = ui.Gradient.radial(p, 11, [
                T.yellow.withValues(alpha: 0.5 * f.spark),
                T.yellow.withValues(alpha: 0),
              ]),
          )
          ..drawCircle(
            p,
            1.7,
            Paint()
              ..color = Color.lerp(
                T.yellow,
                Colors.white,
                0.55,
              )!.withValues(alpha: f.spark),
          );
      }
    }
  }

  /// A line behind each arrow's back end, along the way it came, fading out.
  void _trails(Canvas canvas, _Geometry g, double t, double strength) {
    const samples = 22;
    final poses = [
      for (var j = 0; j <= samples; j++)
        _poseAt(math.max(t - _Beat.trail * j / samples, 0), g.far),
    ];
    // Butt ends: round ones would double up where the segments meet.
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _Look.lineWidth;
    for (final a in g.arrows) {
      Offset? newer;
      for (var j = 0; j <= samples; j++) {
        final pose = poses[j];
        final p = g.centre + _turn(a.back + a.out * pose.spread, pose.turn);
        if (newer != null && (p - newer).distanceSquared > 0.01) {
          final left = 1 - (j - 0.5) / samples;
          paint.color = T.yellow.withValues(
            alpha: 0.7 * strength * left * left,
          );
          canvas.drawLine(newer, p, paint);
        }
        newer = p;
      }
    }
  }

  @override
  bool shouldRepaint(_SwirlPainter old) =>
      old.still != still || old.underlap != underlap;
}

/// The matrix that pushes a resting arrow out by [shift], turns it round the
/// mark's centre by [turn] and puts that centre at [centre].
Float64List _place(Offset centre, double turn, Offset shift) {
  final c = math.cos(turn), s = math.sin(turn);
  final at = centre + _turn(shift, turn);
  return Float64List.fromList([
    c, s, 0, 0, //
    -s, c, 0, 0,
    0, 0, 1, 0,
    at.dx, at.dy, 0, 1,
  ]);
}

// ---------------------------------------------------------------------------
// The TDB mark, in units of half the centre square's side, y down. Copied
// from header_logo_v8.dart.
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
      cut = _turn(_cutOut, k * math.pi / 2);

  /// This piece's turn, radians.
  final double a;

  /// Ring centre, and the centre of the ring it passes under.
  final Offset c, n;

  /// Arrowhead: inner corner, tip and barb. The tip is the next piece's
  /// inner corner.
  final Offset i, t, f;

  /// Inner band edge where it meets the arrowhead, and the outer edge's cut
  /// end — the arrow's back.
  final Offset edgeIn, cut;

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

/// Writes mark units into a [Path], [unit] px per unit, centred on the origin.
class _Pen {
  _Pen(this.unit);

  final double unit;
  final path = Path();

  void moveTo(Offset p) => path.moveTo(p.dx * unit, p.dy * unit);

  void lineTo(Offset p) => path.lineTo(p.dx * unit, p.dy * unit);

  /// Arc round [c] of radius [r]; positive [sweep] runs clockwise.
  void arc(Offset c, double r, double from, double sweep) => path.arcTo(
    Rect.fromCircle(center: c * unit, radius: r * unit),
    from,
    sweep,
    false,
  );
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

/// One arrow, at rest, in px around the mark's centre.
class _Arrow {
  _Arrow(int k, double unit)
    : out = _turn(const Offset(0, -1), k * math.pi / 2) {
    final p = _Piece(k);
    final pen = _Pen(unit)
      ..moveTo(p.cut)
      ..arc(p.c, _rOut, _Piece.aOut + p.a, _axis - _Piece.aOut)
      ..lineTo(p.f)
      ..lineTo(p.t)
      ..lineTo(p.i)
      ..lineTo(p.edgeIn)
      ..arc(p.c, _rIn, _axis + p.a, _Piece.aIn - _axis)
      ..arc(p.n, _rGap, _Piece.bIn + p.a, _Piece.bOut - _Piece.bIn);
    pen.path.close();
    outline = pen.path;
    back = p.cut * unit;
    tip = p.t * unit;
  }

  /// The way this arrow is pushed when the pinwheel spreads: out from the
  /// centre through its own ring.
  final Offset out;

  late final Path outline;

  /// Where the trail leaves the arrow, and where its tip lands.
  late final Offset back, tip;
}

/// The mark laid out for one header size.
class _Geometry {
  _Geometry(this.size, this.underlap) {
    unit = size.width * _Look.width / (2 * _extent);
    centre = Offset(
      size.width * _Look.x,
      size.height - underlap - _Look.anchor - _extent * unit,
    );
    arrows = [for (var k = 0; k < 4; k++) _Arrow(k, unit)];

    // Far enough that even an arrow's tip, its nearest point to the centre,
    // is past the header's furthest corner.
    var corner = 0.0;
    for (final p in [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ]) {
      corner = math.max(corner, (p - centre).distance);
    }
    far = corner + 2 * unit;

    final away = const Offset(-0.55, 0.8) * (_extent * unit);
    _strong = centre + away;
    _faint = centre - away;
  }

  final Size size;
  final double underlap;

  late final double unit, far;
  late final Offset centre;
  late final List<_Arrow> arrows;
  late final Offset _strong, _faint;

  /// Strong toward the mark's lower left, faint toward its upper right.
  ui.Gradient fade(Color from, Color to) =>
      ui.Gradient.linear(_strong, _faint, [from, to]);
}

/// Holds the layout for as long as the size holds still.
class _Cache {
  _Geometry? _geometry;

  void clear() => _geometry = null;

  _Geometry of(Size size, double underlap) {
    var g = _geometry;
    if (g == null || g.size != size || g.underlap != underlap) {
      g = _geometry = _Geometry(size, underlap);
    }
    return g;
  }
}
