import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// v11: four big straight arrows fly in and curl into the TDB mark.
///
/// Each of the mark's four arrows starts as a straight arrow: its curved band
/// unrolled into a straight shaft of the same length and width, with the
/// same head. They glide in head first from just off the header, each along
/// the line its head points down, so the four come from four sides like the
/// arms of a pinwheel. On the way in, each shaft curls round behind its head
/// until it lies on its ring, and the tips land on the centre square's
/// corners with a spark. The mark fills and rests where v8's knot rests.
/// Then the arrows slide straight out to the four sides, as in v10, and come
/// in straight again.
///
/// Self-contained: the mark's geometry is copied from header_logo_v8.dart,
/// which stays as it is, like v9's and v10's.

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
  static const seconds = 14.0;
}

/// Beats of the loop, as fractions of it.
class _Beat {
  // In: the arrows glide in straight, curl on the way, and land.
  static const curlStart = 0.12, curlEnd = 0.38, meet = 0.42;

  // The mark fills as it forms; a spark lights each corner as a tip lands.
  static const fillStart = 0.36, fillEnd = 0.52;
  static const sparkStart = 0.34, sparkEnd = 0.50;

  // Out: the arrows part and slide away. The header stays empty until they
  // come in again.
  static const outStart = 0.72, unfillEnd = 0.82, outEnd = 0.92;
}

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

class HeaderLogoV11 extends StatefulWidget {
  const HeaderLogoV11({super.key, this.underlap = 0});

  /// How far this background runs under the content below it. The mark
  /// rests above that edge.
  final double underlap;

  @override
  State<HeaderLogoV11> createState() => _HeaderLogoV11State();
}

class _HeaderLogoV11State extends State<HeaderLogoV11>
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
  void didUpdateWidget(covariant HeaderLogoV11 old) {
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
        painter: _CurlPainter(
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

double _at(double t, double from, double to) =>
    ((t - from) / (to - from)).clamp(0.0, 1.0);

/// How far the shafts have curled: 0 straight, 1 on their rings. They leave
/// curled.
double _curlAt(double t) => t < _Beat.outStart
    ? Curves.easeInOutSine.transform(_at(t, _Beat.curlStart, _Beat.curlEnd))
    : 1;

/// What else the loop is doing at one moment, each 0–1.
class _Frame {
  const _Frame({required this.formed, required this.spark});

  /// How far the arrows have become one mark: fill, outline alpha, dissolve.
  final double formed;

  /// Glow where the tips meet the square's corners.
  final double spark;

  static const still = _Frame(formed: 1, spark: 0);
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
    );
  }
  return _Frame(formed: 1 - ease(_Beat.outStart, _Beat.unfillEnd), spark: 0);
}

// ---------------------------------------------------------------------------
// Painting
// ---------------------------------------------------------------------------

class _CurlPainter extends CustomPainter {
  _CurlPainter(this.clock, this.cache, this.underlap, this.still)
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

    // Piece 0 bent once, then turned into place as each of the four.
    final bent = [for (final n in _outline) _bend(n, still ? 1 : _curlAt(t))];
    final tip = _bend(_tip, 1);
    final placed = <Path>[];
    final tips = <Offset>[];
    for (var k = 0; k < 4; k++) {
      final a = k * math.pi / 2;
      final at = g.centre + (still ? Offset.zero : g.offsetAt(k, t));
      final path = Path();
      for (var j = 0; j < bent.length; j++) {
        final p = at + _turn(bent[j], a) * g.unit;
        j == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      placed.add(path..close());
      tips.add(at + _turn(tip, a) * g.unit);
    }

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

    // Outlines, stroked opaque into a layer faded as a whole. The outline
    // flares as the tips meet, then settles.
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
    canvas.restore();

    // A spark on each corner of the centre square as a tip lands on it.
    if (f.spark > 0) {
      for (final p in tips) {
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

  @override
  bool shouldRepaint(_CurlPainter old) =>
      old.still != still || old.underlap != underlap;
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

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;

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

// ---------------------------------------------------------------------------
// Bending
//
// Piece 0, the top arrow, is held as nodes in the frame of its head: where
// the head meets the band ([_base]), the way the arrow points ([_along]) and
// out from its ring ([_across]). A band node is how far back along the band
// it sits and how far across; bending lays the band on a circle through the
// base whose curvature runs from none (a straight shaft) to the ring's. Head
// nodes stay rigid.
// ---------------------------------------------------------------------------

const _rMid = (_rIn + _rOut) / 2; // the band's centre line
final _base = const Offset(0, -_ring) + Offset.fromDirection(_axis, _rMid);
final _across = Offset.fromDirection(_axis);
final _along = Offset.fromDirection(_axis + math.pi / 2);

/// One point of the outline: for the band, [s] back along it and [w] out
/// across it; for the head, [s] forward along [_along] and [w] along
/// [_across].
class _Node {
  const _Node.band(this.s, this.w) : head = false;
  const _Node.head(this.s, this.w) : head = true;

  final double s, w;
  final bool head;
}

/// Where [node] lands with the band bent to [curl] of its ring's curvature.
Offset _bend(_Node node, double curl) {
  if (node.head) return _base + _along * node.s + _across * node.w;
  final k = curl / _rMid;
  if (k < 1e-6) return _base - _along * node.s + _across * node.w;
  final a = node.s * k, c = math.cos(a), s = math.sin(a);
  return _base +
      _across * ((c - 1) / k + node.w * c) -
      _along * (s / k + node.w * s);
}

_Node _headNode(Offset p) {
  final d = p - _base;
  return _Node.head(_dot(d, _along), _dot(d, _across));
}

/// Piece 0's tip, which lands on the centre square's lower right corner.
final _tip = _headNode(const Offset(1, 1));

/// Piece 0's outline: outer edge from the cut to the head, the head, inner
/// edge back, and the cut where it passes under the ring before it.
final List<_Node> _outline = () {
  const c0 = Offset(0, -_ring), n0 = Offset(-_ring, 0);
  final cutOut = _meet(c0, _rOut, n0, _rGap);
  final cutIn = _meet(c0, _rIn, n0, _rGap);

  _Node band(Offset p) {
    final d = p - c0;
    return _Node.band(_rMid * (_axis - d.direction), d.distance - _rMid);
  }

  /// Points round [c] from angle [from] to [to], about 3° apart.
  List<Offset> arc(Offset c, double r, double from, double to) {
    final n = math.max(2, ((to - from).abs() / 0.05).ceil());
    return [
      for (var j = 0; j <= n; j++)
        c + Offset.fromDirection(from + (to - from) * j / n, r),
    ];
  }

  return [
    for (final p in arc(c0, _rOut, (cutOut - c0).direction, _axis)) band(p),
    _headNode(const Offset(3, 1)),
    _tip,
    _headNode(const Offset(1, -1)),
    for (final p in arc(c0, _rIn, _axis, (cutIn - c0).direction)) band(p),
    for (final p in arc(
      n0,
      _rGap,
      (cutIn - n0).direction,
      (cutOut - n0).direction,
    ).skip(1))
      band(p),
  ];
}();

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

/// The mark laid out for one header size.
class _Geometry {
  _Geometry(this.size, this.underlap) {
    unit = size.width * _Look.width / (2 * _extent);
    centre = Offset(
      size.width * _Look.x,
      size.height - underlap - _Look.anchor - _extent * unit,
    );

    // Far enough out to the sides that even an arrow's tip, its nearest
    // point to the centre, is past the header's furthest corner.
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

    // Coming in, each straight arrow starts just off the header, back along
    // the line its head points down.
    final straight = [for (final n in _outline) _bend(n, 0)];
    final seen = bounds.inflate(8);
    for (var k = 0; k < 4; k++) {
      final a = k * math.pi / 2;
      final back = -_turn(_along, a);
      var d = 0.0;
      while (d < far &&
          straight.any((p) => seen.contains(_px(back * d, p, a)))) {
        d += 4;
      }
      _start.add(d);
    }

    final away = const Offset(-0.55, 0.8) * (_extent * unit);
    _strong = centre + away;
    _faint = centre - away;
  }

  final Size size;
  final double underlap;

  late final double unit, far;
  late final Offset centre;
  final _start = <double>[];
  late final Offset _strong, _faint;

  Rect get bounds => Offset.zero & size;

  /// A point of piece 0 in mark units, turned by [a] into piece k and moved
  /// by [offset], in px.
  Offset _px(Offset offset, Offset p, double a) =>
      centre + offset + _turn(p, a) * unit;

  /// How far arrow [k] is from its place at [t], px.
  Offset offsetAt(int k, double t) {
    final a = k * math.pi / 2;
    if (t < _Beat.outStart) {
      // Steady at first, then a soft landing.
      final left = 1 - Curves.easeOutQuad.transform(_at(t, 0, _Beat.meet));
      return _turn(_along, a) * (-_start[k] * left);
    }
    // Out to its own side, gently at first, then faster.
    final going = Curves.easeInCubic.transform(
      _at(t, _Beat.outStart, _Beat.outEnd),
    );
    return _turn(const Offset(0, -1), a) * (far * going);
  }

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
