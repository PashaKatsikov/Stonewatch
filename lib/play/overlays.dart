import 'package:flutter/material.dart';

import '../format.dart';
import '../game/art.dart';
import '../game/rules.dart';
import '../game/session.dart';
import 'hazard.dart';

class PlacedToast extends StatelessWidget {
  const PlacedToast({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E9D4A),
      borderRadius: BorderRadius.circular(8),
      elevation: 6,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Your bet is placed!',
                style: TextStyle(
                  fontFamily: displayFont,
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.white, size: 18),
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }
}

class OutcomeBanner extends StatelessWidget {
  const OutcomeBanner({super.key, required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final win = session.phase == RoundPhase.celebrating;
    return Material(
      color: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const HazardStripe(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: win
                    ? const [
                        Color(0xF01C140C),
                        Color(0xFF3A2612),
                        Color(0xFF140E0A),
                      ]
                    : const [
                        Color(0xF01A0E12),
                        Color(0xFF3A1420),
                        Color(0xFF12080C),
                      ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: win ? _win(session.winAmount) : const _Oops(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _win(double amount) {
    return Column(
      children: [
        const Text(
          'YOU WIN',
          style: TextStyle(
            fontFamily: displayFont,
            fontSize: 40,
            height: 1,
            color: Color(0xFFFFE14A),
            shadows: [Shadow(color: Color(0xAA000000), offset: Offset(0, 3))],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${formatAmount(amount)} FUN',
          style: const TextStyle(
            fontFamily: displayFont,
            fontSize: 22,
            color: Colors.white,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _Oops extends StatelessWidget {
  const _Oops();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 54,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final asset in blockAssets.take(4))
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Transform.rotate(
                    angle: asset.hashCode.isEven ? -0.4 : 0.35,
                    child: Image.asset(asset, height: 48),
                  ),
                ),
            ],
          ),
        ),
        const Text(
          'OOPS!',
          style: TextStyle(
            fontFamily: displayFont,
            fontSize: 48,
            height: 1,
            color: Colors.white,
            shadows: [
              Shadow(color: Color(0xFFE53935), offset: Offset(0, 3)),
              Shadow(color: Color(0xAA000000), blurRadius: 8),
            ],
          ),
        ),
      ],
    );
  }
}

class HintOverlay extends StatelessWidget {
  const HintOverlay({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: ColoredBox(
        color: const Color(0xB0000000),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Text(
                    'i',
                    style: TextStyle(
                      fontFamily: displayFont,
                      color: Colors.white,
                      fontSize: 28,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _CoefLine(label: 'Minimum Coefficient: ', value: 'x0.4'),
                const SizedBox(height: 6),
                const _CoefLine(
                  label: 'Maximum Win Coefficient: ',
                  value: 'Unlimited',
                ),
                const SizedBox(height: 18),
                Text(
                  'Tap to close',
                  style: TextStyle(
                    fontFamily: displayFont,
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoefLine extends StatelessWidget {
  const _CoefLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(
          fontFamily: displayFont,
          fontSize: 16,
          color: Colors.white,
          height: 1.25,
        ),
        children: [
          TextSpan(text: label),
          TextSpan(
            text: value,
            style: const TextStyle(color: Color(0xFFFFB300)),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class GameMenu extends StatelessWidget {
  const GameMenu({
    super.key,
    required this.onClose,
    required this.onHow,
    required this.onPrivacy,
    required this.onSupport,
  });

  final VoidCallback onClose;
  final VoidCallback onHow;
  final VoidCallback onPrivacy;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: ColoredBox(
        color: const Color(0xC0000000),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: GestureDetector(
              onTap: () {},
              child: Material(
                color: const Color(0xFF1A222C),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const HazardStripe(height: 10),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Row(
                        children: [
                          const Spacer(),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: Image.asset(logoAsset, height: 92),
                    ),
                    const SizedBox(height: 8),
                    _MenuRow(label: 'How to Play', onTap: onHow),
                    _MenuRow(label: 'Privacy Policy', onTap: onPrivacy),
                    _MenuRow(label: 'Support', onTap: onSupport),
                    const SizedBox(height: 12),
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

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: displayFont,
                  color: Colors.white,
                  fontSize: 18,
                ),
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFFFE14A)),
          ],
        ),
      ),
    );
  }
}

class HowToPlay extends StatelessWidget {
  const HowToPlay({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: ColoredBox(
        color: const Color(0xC0000000),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: GestureDetector(
              onTap: () {},
              child: Material(
                color: const Color(0xFF1A222C),
                borderRadius: BorderRadius.circular(18),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'How to Play',
                              style: TextStyle(
                                fontFamily: displayFont,
                                color: Color(0xFFFFE14A),
                                fontSize: 22,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: onClose,
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          'Set a bet and press BUILD. The crane swings a floor over the street.\n\n'
                          'Press BUILD again to drop it. A clean landing multiplies your bet. '
                          'The lowest coefficient is ${formatMult(minCoefficient)}. '
                          'There is no maximum.\n\n'
                          'Land wide of the roof and the tower comes down. The bet is lost.\n\n'
                          'Cash out any time after a floor sticks. The swing gets faster as the tower grows.',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
