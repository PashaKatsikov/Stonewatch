import 'package:flutter/material.dart';

import 'backdrops.dart';
import 'gate_buttons.dart';

// ============================================================
// NO SIGNAL VIEW — the no-connection screen
// ============================================================
// There is no dedicated art for this state, so it reuses the loading
// backdrop and draws a signboard panel on top carrying the fixed
// copy plus a Retry button. Retry rebuilds the caller-supplied route
// through pushReplacement — for the boot path that re-runs the whole
// decision pipeline fresh.
//
// Landscape has NO SafeArea and the panel is centred horizontally, so
// a side camera cutout never skews the layout.
// ============================================================

class NoSignalView extends StatefulWidget {
  const NoSignalView({super.key, required this.rebuild});

  final WidgetBuilder rebuild;

  @override
  State<NoSignalView> createState() => _NoSignalViewState();
}

class _NoSignalViewState extends State<NoSignalView> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.rebuild),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.sizeOf(context);
    final bool landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final double panelWidth =
        landscape ? size.width * 0.6 : size.width * 0.86;

    return Scaffold(
      backgroundColor: const Color(0xFF1B2A3C),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            landscape
                ? Backdrops.noSignalLandscape
                : Backdrops.noSignalPortrait,
            fit: BoxFit.cover,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0x66000000),
            ),
          ),
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: panelWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  _SignPanel(),
                  SizedBox(height: landscape ? 18 : 24),
                  if (_retrying)
                    const SizedBox(
                      height: 36,
                      width: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFFC94D)),
                      ),
                    )
                  else
                    WardenButton(
                      label: 'Retry',
                      width: landscape ? size.width * 0.3 : size.width * 0.55,
                      onTap: _retry,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 22),
      decoration: BoxDecoration(
        color: const Color(0xF21F2A38),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0A106), width: 3),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x80000000),
            offset: Offset(0, 6),
            blurRadius: 16,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const <Widget>[
          Text(
            'NO INTERNET CONNECTION',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Lilita',
              color: Color(0xFFFFD75A),
              fontSize: 24,
              height: 1.1,
              letterSpacing: 0.5,
              shadows: <Shadow>[
                Shadow(
                  color: Color(0xAA000000),
                  offset: Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Text(
            'Check your connection and try again',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}
