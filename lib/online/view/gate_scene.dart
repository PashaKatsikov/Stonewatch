import 'dart:math' as math;

import 'package:flutter/material.dart';

// ============================================================
// GATE SCENE — hand-painted construction backdrop
// ============================================================
// The notify-invite and no-signal screens share this fully painted
// scene instead of shipping bespoke webp artwork (which would be a
// cross-submission fingerprint — see .cursor rules: custom screens,
// and the Blazebound reference, which paints its gate screens too).
//
// The scene is the Stonewatch theme at golden hour: a dusk-blue sky
// over a warm horizon, drifting clouds, a city skyline, a tower
// crane hoisting a glowing block and the stacked-stone tower the
// game is built around. CustomPainter resolves against the live
// canvas size, so it composes correctly in BOTH orientations with a
// single code path — portrait raises the crane tall on the left;
// landscape spreads the skyline and seats the tower to the right.
//
// A bottom scrim keeps the gold headline and the buttons legible
// over the artwork. No asset, no decode, orientation-independent.
// ============================================================

class GateScene extends StatelessWidget {
  const GateScene({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bool landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        RepaintBoundary(
          child: CustomPaint(
            painter: _GateScenePainter(landscape: landscape),
            isComplex: true,
          ),
        ),
        ?child,
      ],
    );
  }
}

class _GateScenePainter extends CustomPainter {
  _GateScenePainter({required this.landscape});

  final bool landscape;

  // Theme palette — matches the cartoon-construction game art.
  static const Color _skyTop = Color(0xFF17283F);
  static const Color _skyMid = Color(0xFF2B4A6E);
  static const Color _skyGlow = Color(0xFF6E86A6);
  static const Color _horizon = Color(0xFFE9A53C);
  static const Color _horizonHot = Color(0xFFF6CC6A);
  static const Color _steel = Color(0xFFE0A106);
  static const Color _steelDark = Color(0xFF8A5A10);
  static const Color _skylineFar = Color(0xFF203A57);
  static const Color _skylineNear = Color(0xFF16263B);
  static const Color _stone = Color(0xFF7E95A8);
  static const Color _stoneDark = Color(0xFF55707F);

  @override
  void paint(Canvas canvas, Size size) {
    final double h = size.height;
    // Horizon sits higher in landscape so the skyline has room to spread.
    final double horizonY = h * (landscape ? 0.70 : 0.74);

    _paintSky(canvas, size, horizonY);
    _paintSun(canvas, size, horizonY);
    _paintClouds(canvas, size, horizonY);
    _paintSkyline(canvas, size, horizonY);
    _paintGround(canvas, size, horizonY);
    _paintTower(canvas, size, horizonY);
    _paintCrane(canvas, size, horizonY);
    _paintScrim(canvas, size);
  }

  void _paintSky(Canvas canvas, Size size, double horizonY) {
    final Rect full = Offset.zero & size;
    canvas.drawRect(
      full,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[_skyTop, _skyMid, _skyGlow, _horizon, _horizonHot],
          stops: <double>[0.0, 0.34, 0.56, 0.72, 0.82],
        ).createShader(full),
    );
  }

  void _paintSun(Canvas canvas, Size size, double horizonY) {
    final Offset c = Offset(size.width * (landscape ? 0.72 : 0.68), horizonY);
    final double r = size.shortestSide * 0.42;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _horizonHot.withValues(alpha: 0.9),
            _horizon.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: r)),
    );
  }

  void _paintClouds(Canvas canvas, Size size, double horizonY) {
    final double w = size.width;
    final double h = size.height;
    // (cx, cy, scale, opacity) in fractions of the canvas.
    final List<List<double>> clouds = <List<double>>[
      <double>[0.22, 0.16, 1.0, 0.85],
      <double>[0.74, 0.12, 0.72, 0.65],
      <double>[0.52, 0.30, 0.9, 0.5],
      if (landscape) <double>[0.90, 0.26, 0.6, 0.4],
    ];
    for (final List<double> c in clouds) {
      _puffyCloud(
        canvas,
        Offset(w * c[0], h * c[1]),
        size.shortestSide * 0.16 * c[2],
        Colors.white.withValues(alpha: c[3]),
      );
    }
  }

  void _puffyCloud(Canvas canvas, Offset center, double r, Color color) {
    final Paint p = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(center, r, p);
    canvas.drawCircle(center.translate(r * 0.95, r * 0.18), r * 0.78, p);
    canvas.drawCircle(center.translate(-r * 0.95, r * 0.22), r * 0.72, p);
    canvas.drawCircle(center.translate(r * 0.1, -r * 0.45), r * 0.66, p);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center.dx - r * 1.7,
          center.dy + r * 0.2,
          r * 3.4,
          r * 0.9,
        ),
        Radius.circular(r),
      ),
      p,
    );
  }

  void _paintSkyline(Canvas canvas, Size size, double horizonY) {
    final double w = size.width;
    // Two parallax rows of simple buildings fading toward the horizon.
    _buildingRow(
      canvas,
      w,
      horizonY - 2,
      _skylineFar,
      seed: 7,
      count: landscape ? 12 : 8,
      minH: size.height * 0.05,
      maxH: size.height * 0.14,
    );
    _buildingRow(
      canvas,
      w,
      horizonY + size.height * 0.015,
      _skylineNear,
      seed: 19,
      count: landscape ? 9 : 6,
      minH: size.height * 0.07,
      maxH: size.height * 0.2,
    );
  }

  void _buildingRow(
    Canvas canvas,
    double w,
    double baseY,
    Color color, {
    required int seed,
    required int count,
    required double minH,
    required double maxH,
  }) {
    final math.Random rnd = math.Random(seed);
    final Paint p = Paint()..color = color;
    final Paint lit = Paint()..color = _horizonHot.withValues(alpha: 0.5);
    final double step = w / count;
    for (int i = 0; i < count; i++) {
      final double bw = step * (0.6 + rnd.nextDouble() * 0.3);
      final double bh = minH + rnd.nextDouble() * (maxH - minH);
      final double x = i * step + (step - bw) / 2;
      final Rect b = Rect.fromLTWH(x, baseY - bh, bw, bh);
      canvas.drawRect(b, p);
      // A couple of warm-lit windows catching the horizon glow.
      final int cols = 2 + rnd.nextInt(2);
      final int rows = (bh / (minH)).clamp(1, 4).toInt() + 1;
      final double cw = bw / (cols * 2 + 1);
      final double ch = bh / (rows * 2 + 1);
      for (int r = 0; r < rows; r++) {
        for (int cI = 0; cI < cols; cI++) {
          if (rnd.nextDouble() < 0.45) continue;
          canvas.drawRect(
            Rect.fromLTWH(
              b.left + cw * (cI * 2 + 1),
              b.top + ch * (r * 2 + 1),
              cw,
              ch,
            ),
            lit,
          );
        }
      }
    }
  }

  void _paintGround(Canvas canvas, Size size, double horizonY) {
    final Rect ground =
        Rect.fromLTWH(0, horizonY, size.width, size.height - horizonY);
    canvas.drawRect(
      ground,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Color(0xFF2A3647), Color(0xFF141C27)],
        ).createShader(ground),
    );
    // Soft horizon haze line.
    canvas.drawRect(
      Rect.fromLTWH(0, horizonY - 2, size.width, 4),
      Paint()..color = _horizonHot.withValues(alpha: 0.35),
    );
  }

  void _paintTower(Canvas canvas, Size size, double horizonY) {
    // Stacked-stone tower — the core game object. Centre-bottom in
    // portrait, nudged right in landscape to clear the crane mast.
    final double baseCx = size.width * (landscape ? 0.64 : 0.5);
    final double baseW = size.shortestSide * (landscape ? 0.2 : 0.26);
    final double blockH = baseW * 0.42;
    final double baseY = horizonY + size.height * 0.02;

    // Foundation slab.
    _block(
      canvas,
      Rect.fromCenter(
        center: Offset(baseCx, baseY - blockH * 0.5),
        width: baseW * 1.2,
        height: blockH,
      ),
      _stoneDark,
      _stone,
    );

    final List<double> jitter = <double>[-0.06, 0.05, -0.03, 0.02, -0.01];
    double y = baseY - blockH;
    for (int i = 0; i < jitter.length; i++) {
      final double cx = baseCx + baseW * jitter[i];
      final Rect r = Rect.fromCenter(
        center: Offset(cx, y - blockH * 0.5),
        width: baseW * (1.0 - i * 0.04),
        height: blockH,
      );
      _block(canvas, r, _stone, _stoneDark);
      y -= blockH;
    }
  }

  void _block(Canvas canvas, Rect r, Color face, Color edge) {
    final RRect rr =
        RRect.fromRectAndRadius(r, Radius.circular(r.height * 0.18));
    canvas.drawRRect(
      rr.shift(const Offset(0, 3)),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[face, edge],
        ).createShader(r),
    );
    canvas.drawRRect(
      rr.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _paintCrane(Canvas canvas, Size size, double horizonY) {
    final double w = size.width;
    final double h = size.height;
    final Paint steel = Paint()
      ..color = _steel
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.018
      ..strokeCap = StrokeCap.round;
    final Paint steelThin = Paint()
      ..color = _steelDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.009;

    // Mast on the left; a touch shorter and further left in landscape.
    final double mastX = w * (landscape ? 0.14 : 0.2);
    final double mastTop = h * (landscape ? 0.14 : 0.1);
    final double mastBase = horizonY + h * 0.03;
    final double mastHalf = size.shortestSide * 0.035;

    _latticeColumn(canvas, mastX, mastTop, mastBase, mastHalf, steel, steelThin);

    // Jib reaching right over the tower; short counter-jib left.
    final double jibY = mastTop + mastHalf * 0.4;
    final double jibEnd = w * (landscape ? 0.6 : 0.74);
    final double counterEnd = mastX - w * 0.1;
    _latticeBeam(canvas, counterEnd, mastX + mastHalf, jibY, mastHalf * 0.8,
        steel, steelThin);
    _latticeBeam(
        canvas, mastX - mastHalf, jibEnd, jibY, mastHalf * 0.9, steel, steelThin);

    // Cab at the mast head.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(mastX - mastHalf, jibY + mastHalf * 0.8,
            mastHalf * 2, mastHalf * 1.6),
        Radius.circular(mastHalf * 0.4),
      ),
      Paint()..color = _steelDark,
    );

    // Counterweight.
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(counterEnd + 6, jibY + mastHalf * 0.8),
        width: mastHalf * 1.4,
        height: mastHalf * 1.8,
      ),
      Paint()..color = _steelDark,
    );

    // Apex + tension cables to both jib tips.
    final Offset apex = Offset(mastX, mastTop - mastHalf * 1.4);
    canvas.drawLine(apex, Offset(jibEnd, jibY), steelThin);
    canvas.drawLine(apex, Offset(counterEnd, jibY), steelThin);
    canvas.drawLine(apex, Offset(mastX, mastTop), steel);

    // Hoist cable + a glowing block being lifted toward the tower.
    final double hookX = w * (landscape ? 0.5 : 0.62);
    final double blockTop = jibY + h * 0.12;
    canvas.drawLine(
      Offset(hookX, jibY),
      Offset(hookX, blockTop),
      steelThin,
    );
    final double bw = size.shortestSide * 0.12;
    final Rect lift = Rect.fromCenter(
      center: Offset(hookX, blockTop + bw * 0.3),
      width: bw,
      height: bw * 0.52,
    );
    // Lift glow.
    canvas.drawCircle(
      lift.center,
      bw * 0.9,
      Paint()
        ..shader = RadialGradient(
          colors: <Color>[
            _horizonHot.withValues(alpha: 0.55),
            _horizonHot.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: lift.center, radius: bw * 0.9)),
    );
    _block(canvas, lift, _horizonHot, _steel);
  }

  void _latticeColumn(Canvas canvas, double cx, double top, double bottom,
      double half, Paint rail, Paint web) {
    canvas.drawLine(Offset(cx - half, top), Offset(cx - half, bottom), rail);
    canvas.drawLine(Offset(cx + half, top), Offset(cx + half, bottom), rail);
    final double span = bottom - top;
    final int segs = (span / (half * 1.6)).clamp(4, 40).toInt();
    final double sh = span / segs;
    for (int i = 0; i < segs; i++) {
      final double y0 = top + i * sh;
      final double y1 = y0 + sh;
      if (i.isEven) {
        canvas.drawLine(Offset(cx - half, y0), Offset(cx + half, y1), web);
      } else {
        canvas.drawLine(Offset(cx + half, y0), Offset(cx - half, y1), web);
      }
      canvas.drawLine(Offset(cx - half, y1), Offset(cx + half, y1), web);
    }
  }

  void _latticeBeam(Canvas canvas, double x0, double x1, double cy,
      double half, Paint rail, Paint web) {
    canvas.drawLine(Offset(x0, cy - half), Offset(x1, cy - half), rail);
    canvas.drawLine(Offset(x0, cy + half), Offset(x1, cy + half), rail);
    final double span = (x1 - x0).abs();
    final double dir = x1 >= x0 ? 1 : -1;
    final int segs = (span / (half * 1.8)).clamp(3, 40).toInt();
    final double sw = span / segs;
    for (int i = 0; i < segs; i++) {
      final double xa = x0 + dir * i * sw;
      final double xb = xa + dir * sw;
      if (i.isEven) {
        canvas.drawLine(Offset(xa, cy - half), Offset(xb, cy + half), web);
      } else {
        canvas.drawLine(Offset(xa, cy + half), Offset(xb, cy - half), web);
      }
      canvas.drawLine(Offset(xb, cy - half), Offset(xb, cy + half), web);
    }
  }

  void _paintScrim(Canvas canvas, Size size) {
    final Rect lower = Rect.fromLTWH(
      0,
      size.height * 0.52,
      size.width,
      size.height * 0.48,
    );
    canvas.drawRect(
      lower,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            const Color(0x00101820),
            const Color(0x99101820),
            const Color(0xD9101820),
          ],
          stops: const <double>[0.0, 0.55, 1.0],
        ).createShader(lower),
    );
  }

  @override
  bool shouldRepaint(_GateScenePainter oldDelegate) =>
      oldDelegate.landscape != landscape;
}
