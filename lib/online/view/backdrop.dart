import 'package:flutter/material.dart';

// ============================================================
// GATE BACKDROP — shared gradient fill for the gateway surfaces
// ============================================================
// The notify-invite and no-signal screens no longer ship bespoke
// artwork. They share this gradient, styled to match the app theme
// (deep construction-site navy with a warm gold glow), so a text
// overlay reads cleanly in both orientations. Fully painted — no
// asset, no decode, orientation-independent.
// ============================================================

class Backdrop extends StatelessWidget {
  const Backdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0xFF24374E),
            Color(0xFF18222D),
            Color(0xFF10161C),
          ],
          stops: <double>[0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          // Warm gold glow drifting down from the top.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.75),
                radius: 1.1,
                colors: <Color>[Color(0x33E0A106), Color(0x00000000)],
                stops: <double>[0.0, 1.0],
              ),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}
