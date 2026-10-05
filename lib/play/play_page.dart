import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/cheat.dart';
import '../config/links.dart';
import '../format.dart';
import '../game/art.dart';
import '../game/session.dart';
import '../shell/web_page.dart';
import 'controls.dart';
import 'overlays.dart';
import 'stage.dart';

class PlayPage extends StatefulWidget {
  const PlayPage({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage> {
  late final Session session;
  final _relay = DropRelay();
  var _menu = false;
  var _how = false;
  var _hint = false;
  var _toastArmed = false;
  var _outcomeBeat = -1;
  Timer? _toastTimer;
  Timer? _outcomeTimer;

  @override
  void initState() {
    super.initState();
    session = Session(
      balance: widget.prefs.getDouble('balance') ?? startingBalance,
      bet: widget.prefs.getDouble('bet') ?? startingBet,
      onBank: (balance, bet) {
        widget.prefs.setDouble('balance', balance);
        widget.prefs.setDouble('bet', bet);
      },
    );
    session.addListener(_onSession);
    _hint = !(widget.prefs.getBool('hint_done') ?? false);
  }

  @override
  void dispose() {
    _toastTimer?.cancel();
    _outcomeTimer?.cancel();
    session.removeListener(_onSession);
    session.dispose();
    super.dispose();
  }

  void _onSession() {
    if (session.showPlaced && !_toastArmed) {
      _toastArmed = true;
      _toastTimer?.cancel();
      _toastTimer = Timer(const Duration(milliseconds: 2300), () {
        if (!mounted) return;
        session.dismissPlaced();
      });
    }
    if (!session.showPlaced) {
      _toastArmed = false;
      _toastTimer?.cancel();
    }

    final outcome =
        session.phase == RoundPhase.celebrating ||
        session.phase == RoundPhase.busting;
    if (outcome && _outcomeBeat != session.beat) {
      _outcomeBeat = session.beat;
      final token = session.beat;
      final bust = session.phase == RoundPhase.busting;
      _outcomeTimer?.cancel();
      _outcomeTimer = Timer(Duration(milliseconds: bust ? 1900 : 2200), () {
        if (!mounted || session.beat != token) return;
        session.backToBetting(newPiece: bust);
      });
    }
    if (mounted) setState(() {});
  }

  void _closeHint() {
    widget.prefs.setBool('hint_done', true);
    setState(() => _hint = false);
  }

  void _openWeb(String title, String url) {
    setState(() {
      _menu = false;
      _how = false;
    });
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WebPage(title: title, url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final blocked = _menu || _how || _hint;
    final outcome =
        session.phase == RoundPhase.celebrating ||
        session.phase == RoundPhase.busting;
    return PopScope(
      canPop: !blocked,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        setState(() {
          if (_how) {
            _how = false;
          } else {
            _menu = false;
            _hint = false;
          }
        });
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF8EC8E3),
        body: Stack(
          children: [
            Column(
              children: [
                _header(context),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final room = constraints.maxHeight;
                      final dockMax = room <= 160 ? room * 0.7 : room - 120;
                      return Column(
                        children: [
                          Expanded(
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: Stage(
                                    session: session,
                                    relay: _relay,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 10,
                                  child: _DotsButton(
                                    onTap: () => setState(() => _hint = true),
                                  ),
                                ),
                                if (session.results.isNotEmpty)
                                  Positioned(
                                    top: 52,
                                    right: 10,
                                    child: _Results(values: session.results),
                                  ),
                                if (session.showPlaced)
                                  Positioned(
                                    top: 8,
                                    left: 56,
                                    right: 56,
                                    child: PlacedToast(
                                      onClose: session.dismissPlaced,
                                    ),
                                  ),
                                if (cheatsEnabled)
                                  Positioned(
                                    left: 8,
                                    top: 8,
                                    child: _CheatPad(session: session),
                                  ),
                              ],
                            ),
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: dockMax),
                            child: ControlDock(
                              session: session,
                              onBuild: () => _relay.drop?.call(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            if (outcome)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: OutcomeBanner(session: session),
                ),
              ),
            if (_menu)
              Positioned.fill(
                child: GameMenu(
                  onClose: () => setState(() => _menu = false),
                  onHow: () => setState(() {
                    _menu = false;
                    _how = true;
                  }),
                  onPrivacy: () => _openWeb('Privacy Policy', privacyPolicyUrl),
                  onSupport: () => _openWeb('Support', supportUrl),
                ),
              ),
            if (_how)
              Positioned.fill(
                child: HowToPlay(onClose: () => setState(() => _how = false)),
              ),
            if (_hint) Positioned.fill(child: HintOverlay(onClose: _closeHint)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: top + 62,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(plateAsset, fit: BoxFit.cover),
          Padding(
            padding: EdgeInsets.fromLTRB(10, top + 6, 12, 6),
            child: Row(
              children: [
                _RoundButton(
                  label: 'Menu',
                  onTap: () => setState(() => _menu = true),
                  child: const Icon(Icons.menu, color: Colors.white),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'ID : ${session.roundId}',
                      style: TextStyle(
                        fontFamily: displayFont,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 11,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: formatAmount(session.balance)),
                            const TextSpan(
                              text: ' FUN',
                              style: TextStyle(
                                color: Color(0xFFFFE14A),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          fontFamily: displayFont,
                          color: Colors.white,
                          fontSize: 20,
                          height: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final newestFirst = values.reversed.toList();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 230),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Text(
            'Results',
            style: TextStyle(
              fontFamily: displayFont,
              color: Colors.white,
              fontSize: 12,
              shadows: [Shadow(color: Color(0xAA000000), blurRadius: 4)],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [for (final value in newestFirst) _chip(value)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(double value) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7EF),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Text(
        formatMult(value),
        style: TextStyle(
          fontFamily: displayFont,
          fontSize: 13,
          height: 1,
          color: value >= 1 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.onTap,
    required this.child,
  });

  final String label;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xCC101418),
            borderRadius: BorderRadius.circular(10),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _DotsButton extends StatelessWidget {
  const _DotsButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Game info',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF3EC6FF),
            boxShadow: [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.more_horiz, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _CheatPad extends StatefulWidget {
  const _CheatPad({required this.session});

  final Session session;

  @override
  State<_CheatPad> createState() => _CheatPadState();
}

class _CheatPadState extends State<_CheatPad> {
  var _open = false;

  void _toggle() => setState(() => _open = !_open);

  @override
  Widget build(BuildContext context) {
    if (!_open) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: const SizedBox(width: 76, height: 32),
      );
    }
    final lucky = Cheat.lucky;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggle,
          child: const SizedBox(width: 76, height: 32),
        ),
        Material(
          color: const Color(0xE6141A22),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
            _chip(
              lucky ? 'Lucky on' : 'Lucky off',
              lucky ? const Color(0xFF1E9D4A) : const Color(0xFF2A3440),
              () {
                Cheat.toggleLucky();
                setState(() {});
              },
            ),
            _chip(
              Cheat.aim == CheatAim.miss ? 'Miss armed' : 'Force miss',
              const Color(0xFF8E2A2A),
              () {
                Cheat.armMiss();
                setState(() {});
              },
            ),
            _chip('+100 000', const Color(0xFF1C5FDB), () {
              widget.session.grant(100000);
            }),
            _chip('Empty wallet', const Color(0xFF5C4A32), widget.session.wipe),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: displayFont,
                color: Colors.white,
                fontSize: 12,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
