import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';
import '../game/art.dart';
import '../game/session.dart';
import 'hazard.dart';

class ControlDock extends StatelessWidget {
  const ControlDock({super.key, required this.session, required this.onBuild});

  final Session session;
  final VoidCallback onBuild;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final inRound = !session.betting;
    final column = Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, bottom + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
            SizedBox(
              height: 16,
              width: double.infinity,
              child: Image.asset(plateAsset, fit: BoxFit.cover),
            ),
            const SizedBox(height: 8),
            if (session.broke && session.betting)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton(
                  onPressed: session.refill,
                  child: const Text(
                    'Refill 100 000 FUN',
                    style: TextStyle(
                      fontFamily: displayFont,
                      color: Color(0xFFFFE14A),
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            if (inRound)
              SizedBox(
                height: 64,
                child: Row(
                  children: [
                    Expanded(
                      child: CashoutButton(
                        amount: session.payout,
                        onPressed: session.canCashOut ? session.cashOut : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ArtButton(
                        asset: buildAsset,
                        label: 'Build',
                        fit: BoxFit.fill,
                        onPressed: session.phase == RoundPhase.live
                            ? onBuild
                            : null,
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              _BetRow(session: session),
              const SizedBox(height: 8),
              _BuildButton(onPressed: session.broke ? null : onBuild),
            ],
          ],
        ),
    );
    return ColoredBox(
      color: const Color(0xFF12181E),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (!constraints.hasBoundedHeight ||
              !constraints.hasBoundedWidth) {
            return column;
          }
          return SizedBox(
            width: constraints.maxWidth,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.bottomCenter,
              child: SizedBox(width: constraints.maxWidth, child: column),
            ),
          );
        },
      ),
    );
  }
}

class _BetRow extends StatelessWidget {
  const _BetRow({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const allInAspect = 266 / 146;
        const betAspect = 587 / 173;
        const doubleAspect = 266 / 146;
        const sum = allInAspect + betAspect + doubleAspect;
        final height = (constraints.maxWidth - 12) / sum;
        return SizedBox(
          height: height,
          child: Row(
            children: [
              Expanded(
                flex: (allInAspect * 100).round(),
                child: ArtButton(
                  asset: allInAsset,
                  label: 'All in',
                  onPressed: session.broke ? null : session.allIn,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: (betAspect * 100).round(),
                child: _BetPlate(session: session),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: (doubleAspect * 100).round(),
                child: ArtButton(
                  asset: doubleAsset,
                  label: 'Double bet',
                  onPressed: session.broke ? null : session.doubleBet,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BuildButton extends StatelessWidget {
  const _BuildButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1249 / 214,
      child: ArtButton(asset: buildAsset, label: 'Build', onPressed: onPressed),
    );
  }
}

class ArtButton extends StatefulWidget {
  const ArtButton({
    super.key,
    required this.asset,
    required this.label,
    required this.onPressed,
    this.fit = BoxFit.contain,
  });

  final String asset;
  final String label;
  final VoidCallback? onPressed;
  final BoxFit fit;

  @override
  State<ArtButton> createState() => _ArtButtonState();
}

class _ArtButtonState extends State<ArtButton> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                HapticFeedback.selectionClick();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 70),
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Image.asset(
              widget.asset,
              fit: widget.fit,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

class _BetPlate extends StatefulWidget {
  const _BetPlate({required this.session});

  final Session session;

  @override
  State<_BetPlate> createState() => _BetPlateState();
}

class _BetPlateState extends State<_BetPlate> {
  Timer? _timer;
  var _hold = 0;
  var _down = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _stop() {
    _hold++;
    _timer?.cancel();
    _timer = null;
    if (_down) setState(() => _down = false);
  }

  void _start(int direction) {
    _stop();
    final token = ++_hold;
    setState(() => _down = true);
    widget.session.nudgeBet(direction);
    HapticFeedback.selectionClick();
    _timer = Timer(const Duration(milliseconds: 320), () {
      if (token != _hold) return;
      _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
        if (token != _hold) return;
        widget.session.nudgeBet(direction);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Listener(
          onPointerDown: (event) {
            final x = event.localPosition.dx;
            if (x < constraints.maxWidth * 0.30) {
              _start(-1);
            } else if (x > constraints.maxWidth * 0.70) {
              _start(1);
            }
          },
          onPointerUp: (_) => _stop(),
          onPointerCancel: (_) => _stop(),
          child: AnimatedScale(
            scale: _down ? 0.98 : 1,
            duration: const Duration(milliseconds: 70),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: Image.asset(
                    betAsset,
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: 0.42,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatAmount(widget.session.bet),
                      style: const TextStyle(
                        fontFamily: displayFont,
                        fontSize: 22,
                        color: Colors.white,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class CashoutButton extends StatefulWidget {
  const CashoutButton({
    super.key,
    required this.amount,
    required this.onPressed,
  });

  final double amount;
  final VoidCallback? onPressed;

  @override
  State<CashoutButton> createState() => _CashoutButtonState();
}

class _CashoutButtonState extends State<CashoutButton> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Cash out ${formatAmount(widget.amount)} FUN',
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 70),
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF4C97FF), Color(0xFF1C5FDB)],
                ),
                border: Border.all(color: const Color(0xFF9AA6B5), width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0x66000000), offset: Offset(0, 3)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Column(
                  children: [
                    const HazardStripe(height: 6),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'CASHOUT',
                              style: TextStyle(
                                fontFamily: displayFont,
                                color: Colors.white,
                                fontSize: 16,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '${formatAmount(widget.amount)} FUN',
                                style: const TextStyle(
                                  fontFamily: displayFont,
                                  color: Color(0xFFFFE14A),
                                  fontSize: 15,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const HazardStripe(height: 6),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
