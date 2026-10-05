import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../config/cheat.dart';
import '../format.dart';
import '../game/art.dart';
import '../game/session.dart';

class DropRelay {
  void Function()? drop;
}

enum _Motion { idle, falling, tumbling, collapsing }

class Stage extends StatefulWidget {
  const Stage({super.key, required this.session, required this.relay});

  final Session session;
  final DropRelay relay;

  @override
  State<Stage> createState() => _StageState();
}

class _StageState extends State<Stage> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  var _clock = 0.0;
  var _phase = 0.0;
  var _motion = _Motion.idle;
  var _t = 0.0;
  var _camT = 1.0;
  var _dustT = -1.0;
  var _popupT = -1.0;
  var _popupValue = 0.0;
  var _shake = 0.0;
  var _shakeX = 0.0;
  var _frozenX = 0.0;
  var _dropArt = 0;
  var _missDir = 1.0;

  @override
  void initState() {
    super.initState();
    widget.session.addListener(_onSession);
    widget.relay.drop = _drop;
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    widget.relay.drop = null;
    widget.session.removeListener(_onSession);
    _ticker.dispose();
    super.dispose();
  }

  void _onSession() {
    if (widget.session.phase == RoundPhase.betting) {
      _motion = _Motion.idle;
      _camT = 1;
      _dustT = -1;
      _popupT = -1;
    }
    if (mounted) setState(() {});
  }

  void _drop() {
    final session = widget.session;
    if (_motion != _Motion.idle || _camT < 0.98) return;
    if (session.phase == RoundPhase.busting ||
        session.phase == RoundPhase.celebrating) {
      return;
    }
    final art = session.hanging;
    final swung = math.sin(_phase) * session.swingReach;
    final x = Cheat.redirectedX(swung, session.topX) ?? swung;
    if (!session.armDrop()) return;
    _dropArt = art;
    _frozenX = x;
    _motion = _Motion.falling;
    _t = 0;
  }

  void _tick(Duration elapsed) {
    var dt = (elapsed - _last).inMicroseconds / 1000000;
    _last = elapsed;
    if (dt <= 0 || dt > 0.05) dt = 1 / 60;
    _clock += dt;
    _phase += dt * widget.session.swingSpeed;
    if (_shake > 0.15) {
      _shake *= math.exp(-7 * dt);
      _shakeX = math.sin(_clock * 52) * _shake;
    } else {
      _shake = 0;
      _shakeX = 0;
    }
    if (_camT < 1) _camT = math.min(1, _camT + dt / 0.32);
    if (_dustT >= 0 && _dustT < 1) _dustT += dt / 0.65;
    if (_popupT >= 0 && _popupT < 1) _popupT += dt / 1.05;

    switch (_motion) {
      case _Motion.idle:
        break;
      case _Motion.falling:
        _t += dt / 0.38;
        if (_t >= 1) {
          _t = 1;
          _finishFall();
        }
      case _Motion.tumbling:
        _t += dt / 0.46;
        if (_t >= 1) {
          _motion = _Motion.collapsing;
          _t = 0;
        }
      case _Motion.collapsing:
        _t += dt / 0.7;
        if (_t >= 1) {
          _t = 1;
          _motion = _Motion.idle;
        }
    }
    if (mounted) setState(() {});
  }

  void _finishFall() {
    final session = widget.session;
    final topX = session.topX;
    final landing = session.settle(
      _frozenX,
      blockWidthFactor(_dropArt),
      _dropArt,
    );
    if (landing.held) {
      _motion = _Motion.idle;
      _camT = 0;
      _dustT = 0;
      _popupT = 0;
      _popupValue = landing.multiplier;
      _shake = landing.multiplier >= 2 ? 9 : 5;
      HapticFeedback.mediumImpact();
      return;
    }
    _motion = _Motion.tumbling;
    _t = 0;
    _popupT = 0;
    _popupValue = 0;
    _missDir = (_frozenX - topX) >= 0 ? 1 : -1;
    _shake = 14;
    HapticFeedback.heavyImpact();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _scene(constraints.biggest),
    );
  }

  Widget _scene(Size size) {
    final session = widget.session;
    final blockH = size.width * blockHeightFactor;
    final step = blockH * 0.82;
    final foundationH = size.width * foundationHeightFactor;
    final roofY = foundationH * 0.445;
    final anchor = size.height * 0.56;
    final virtualCount = math.max(0.0, session.floors.length - (1 - _camT));
    final surface = roofY - virtualCount * step;
    final collapseP = _collapseAmount(session);
    final resting = size.height - foundationH;
    final worldDy =
        math.max(resting, anchor - surface) +
        collapseP * collapseP * size.height * 0.55;
    final landingTop = worldDy + surface - blockH;
    final showHook =
        _motion == _Motion.idle && session.phase != RoundPhase.busting;
    final showShot = _motion == _Motion.falling || _motion == _Motion.tumbling;

    return ClipRect(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Image.asset(
              backgroundAsset,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.medium,
            ),
          ),
          _cloud(
            asset: cloudAsset,
            width: size.width * 0.42,
            top: size.height * 0.06,
            travel: (_clock * 18) % (size.width + size.width * 0.5),
            fromRight: false,
            stageWidth: size.width,
          ),
          _cloud(
            asset: cloudAltAsset,
            width: size.width * 0.36,
            top: size.height * 0.22,
            travel: (_clock * 11) % (size.width + size.width * 0.46),
            fromRight: true,
            stageWidth: size.width,
          ),
          Opacity(
            opacity: (1 - collapseP).clamp(0, 1),
            child: Transform.translate(
              offset: Offset(_shakeX, worldDy),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 0,
                    width: size.width,
                    height: foundationH,
                    child: Image.asset(
                      foundationAsset,
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  for (var i = 0; i < session.floors.length; i++)
                    _floor(
                      session.floors[i],
                      size,
                      bottom: roofY - i * step,
                      height: blockH,
                    ),
                  if (_dustT >= 0 && _dustT < 1 && session.floors.isNotEmpty)
                    _dust(size, roofY - (session.floors.length - 1) * step),
                ],
              ),
            ),
          ),
          if (showShot) _projectile(size, blockH, landingTop),
          if (showHook) ..._hook(size, blockH),
          if (_popupT >= 0 && _popupT < 1) _popup(size, landingTop),
        ],
      ),
    );
  }

  double _collapseAmount(Session session) {
    if (_motion == _Motion.collapsing) return _t.clamp(0, 1);
    if (session.phase == RoundPhase.busting && _motion == _Motion.idle) {
      return 1;
    }
    return 0;
  }

  Widget _floor(
    Floor floor,
    Size size, {
    required double bottom,
    required double height,
  }) {
    final width = size.width * floor.width;
    final left = size.width / 2 + floor.x * size.width - width / 2;
    return Positioned(
      left: left,
      top: bottom - height,
      width: width,
      height: height,
      child: Image.asset(
        blockAssets[floor.art],
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      ),
    );
  }

  Widget _dust(Size size, double seamY) {
    final t = _dustT.clamp(0.0, 1.0);
    final fade = t < 0.25 ? t / 0.25 : 1 - (t - 0.25) / 0.75;
    final w = size.width * 0.30;
    final floor = widget.session.floors.last;
    final cx = size.width / 2 + floor.x * size.width;
    return Positioned(
      left: cx - w / 2,
      top: seamY - w * 0.62,
      width: w,
      height: w * 0.36,
      child: Opacity(
        opacity: (fade * 0.72).clamp(0, 1),
        child: Row(
          children: [
            Expanded(child: Image.asset(cloudAsset, fit: BoxFit.contain)),
            Expanded(child: Image.asset(cloudAltAsset, fit: BoxFit.contain)),
          ],
        ),
      ),
    );
  }

  Widget _projectile(Size size, double blockH, double endTop) {
    final width = size.width * blockWidthFactor(_dropArt);
    final startTop = size.height * 0.08;
    final fall = _motion == _Motion.falling ? _t.clamp(0.0, 1.0) : 1.0;
    final eased = fall * fall;
    var top = startTop + (endTop - startTop) * eased;
    var dx = 0.0;
    var spin = 0.0;
    if (_motion == _Motion.tumbling) {
      final u = _t.clamp(0.0, 1.0);
      dx = _missDir * u * u * size.width * 0.62;
      top = endTop + u * u * size.height * 0.48;
      spin = _missDir * u * 1.5;
    }
    final left = size.width / 2 + _frozenX * size.width - width / 2 + dx;
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: blockH,
      child: Transform.rotate(
        angle: spin,
        child: Image.asset(
          blockAssets[_dropArt],
          fit: BoxFit.fill,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  List<Widget> _hook(Size size, double blockH) {
    final art = widget.session.hanging;
    final blockW = size.width * blockWidthFactor(art);
    final craneH = math.min(blockH * 0.92, size.height * 0.24);
    final craneW = craneH * craneWidthOverHeight;
    final norm = math.sin(_phase) * widget.session.swingReach;
    final center = size.width / 2 + norm * size.width;
    final hangTop = size.height * 0.10;
    final groupTop = hangTop - craneH + 18;
    final groupW = math.max(craneW, blockW);
    final cableBottom = math.max(0.0, groupTop + craneH * 0.18);
    return [
      Positioned(
        left: center - 1.6,
        top: 0,
        width: 3.2,
        height: cableBottom,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF8A7460), Color(0xFF4E4034)],
            ),
          ),
        ),
      ),
      Positioned(
        left: center - groupW / 2,
        top: groupTop,
        width: groupW,
        child: Transform.rotate(
          angle: math.cos(_phase) * 0.045,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: craneW,
                height: craneH,
                child: Image.asset(
                  craneAsset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -18),
                child: SizedBox(
                  width: blockW,
                  height: blockH,
                  child: Image.asset(
                    blockAssets[art],
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _popup(Size size, double landingTop) {
    final t = _popupT.clamp(0.0, 1.0);
    final scale = t < 0.16
        ? 0.4 + (t / 0.16) * 0.9
        : t < 0.30
        ? 1.3 - ((t - 0.16) / 0.14) * 0.3
        : 1.0;
    final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0);
    final missed = _popupValue <= 0;
    final color = missed
        ? const Color(0xFFE53935)
        : _popupValue < 1
        ? const Color(0xFFFFA726)
        : const Color(0xFFFFE14A);
    final popupH = size.width * 0.22;
    final top = (landingTop - popupH - 6)
        .clamp(size.height * 0.18, size.height * 0.46)
        .toDouble();
    return Positioned(
      left: 0,
      right: 0,
      top: top,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Center(
            child: SizedBox(
              width: size.width * 0.42,
              height: size.width * 0.28,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(cloudAltAsset, fit: BoxFit.contain),
                  Text(
                    formatMult(_popupValue),
                    style: TextStyle(
                      fontFamily: displayFont,
                      fontSize: missed ? 64 : 54,
                      color: color,
                      height: 1,
                      shadows: const [
                        Shadow(color: Color(0xCC000000), offset: Offset(0, 3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _cloud({
    required String asset,
    required double width,
    required double top,
    required double travel,
    required bool fromRight,
    required double stageWidth,
  }) {
    final span = stageWidth + width;
    final left = fromRight
        ? stageWidth - (travel % span)
        : (travel % span) - width;
    return Positioned(
      left: left,
      top: top,
      width: width,
      child: Image.asset(asset, fit: BoxFit.contain),
    );
  }
}
