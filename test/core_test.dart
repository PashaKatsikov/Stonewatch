import 'package:flutter_test/flutter_test.dart';
import 'package:stonewatch/game/art.dart';
import 'package:stonewatch/game/motion.dart';
import 'package:stonewatch/game/rules.dart';
import 'package:stonewatch/game/session.dart';

Session _session({double balance = 1000, double bet = 100, int seed = 1}) =>
    Session(balance: balance, bet: bet, onBank: (_, _) {}, seed: seed);

void main() {
  group('rules', () {
    test('constants come from the core', () {
      expect(foundationWidth, 0.37);
      expect(minCoefficient, 0.4);
      expect(missRatio, 0.38);
      expect(topMultiplier, 25);
      expect(minBet, 10);
      expect(startingBalance, 100000);
      expect(startingBet, 100);
    });

    test('centred block holds in the jackpot band', () {
      final low = judgeLanding(
        blockX: 0,
        blockWidth: 0.2,
        topX: 0,
        topWidth: foundationWidth,
        roll: 0,
      );
      expect(low.held, isTrue);
      expect(low.center, 0);
      expect(low.multiplier, 10);
      final high = judgeLanding(
        blockX: 0,
        blockWidth: 0.2,
        topX: 0,
        topWidth: foundationWidth,
        roll: 0.9999,
      );
      expect(high.multiplier, 25);
    });

    test('block off the edge misses', () {
      final miss = judgeLanding(
        blockX: 0.3,
        blockWidth: 0.2,
        topX: 0,
        topWidth: 0.2,
        roll: 0.5,
      );
      expect(miss.held, isFalse);
      expect(miss.center, 0.3);
      expect(miss.multiplier, 0);
    });

    test('bands and payout rounding', () {
      expect(multiplierForRatio(0.55, 0.5), 1.0);
      expect(multiplierForRatio(0.80, 0.4), 2.5);
      expect(growPayout(100, 1.85), 185);
      expect(growPayout(33.33, 0.45), 15);
    });
  });

  group('session', () {
    test('bet controls stay inside the wallet', () {
      final s = _session();
      addTearDown(s.dispose);
      expect(s.bet, 100);
      s.nudgeBet(1);
      expect(s.bet, 110);
      s.nudgeBet(-1);
      expect(s.bet, 100);
      s.doubleBet();
      expect(s.bet, 200);
      s.allIn();
      expect(s.bet, 1000);
      s.doubleBet();
      expect(s.bet, 1000);
    });

    test('a held drop pays out and cash-out banks it', () {
      final s = _session();
      addTearDown(s.dispose);
      expect(s.armDrop(), isTrue);
      expect(s.balance, 900);
      expect(s.stake, 100);
      expect(s.roundId, inInclusiveRange(100000000, 999999999));
      expect(s.phase, RoundPhase.falling);

      final art = s.hanging;
      final landing = s.settle(0, blockWidthFactor(art), art);
      expect(landing.held, isTrue);
      expect([10.0, 15.0, 25.0], contains(landing.multiplier));
      expect(s.phase, RoundPhase.live);
      expect(s.payout, 100 * landing.multiplier);
      expect(s.hanging, isNot(art));
      expect(s.results, [landing.multiplier]);

      s.cashOut();
      expect(s.phase, RoundPhase.celebrating);
      expect(s.balance, 900 + 100 * landing.multiplier);
      expect(s.winAmount, 100 * landing.multiplier);
    });

    test('a missed drop busts the round', () {
      final s = _session();
      addTearDown(s.dispose);
      s.armDrop();
      final art = s.hanging;
      final landing = s.settle(0.9, blockWidthFactor(art), art);
      expect(landing.held, isFalse);
      expect(s.phase, RoundPhase.busting);
      expect(s.balance, 900);
      s.backToBetting(newPiece: true);
      expect(s.phase, RoundPhase.betting);
      expect(s.floors, isEmpty);
      expect(s.payout, 0);
    });

    test('a broke wallet cannot place and can refill', () {
      final s = _session(balance: 5, bet: 100);
      addTearDown(s.dispose);
      expect(s.broke, isTrue);
      expect(s.bet, 5);
      expect(s.armDrop(), isFalse);
      s.refill();
      expect(s.balance, startingBalance);
      expect(s.bet, startingBet);
      expect(s.broke, isFalse);
    });

    test('negative saved balance opens at zero', () {
      final s = _session(balance: -40);
      addTearDown(s.dispose);
      expect(s.balance, 0);
    });

    test('swing grows with the tower', () {
      final s = _session();
      addTearDown(s.dispose);
      expect(s.swingReach, 0.26);
      expect(s.swingSpeed, 2.15);
      s.armDrop();
      final art = s.hanging;
      s.settle(0, blockWidthFactor(art), art);
      expect(s.swingReach, closeTo(0.278, 1e-12));
      expect(s.swingSpeed, greaterThan(2.15 + 0.28));
    });

    test('same seed replays the same round', () {
      final a = _session(seed: 77);
      final b = _session(seed: 77);
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      expect(a.hanging, b.hanging);
      a.armDrop();
      b.armDrop();
      expect(a.roundId, b.roundId);
    });
  });

  group('motion', () {
    test('kinematics match the stage timings', () {
      expect(Motion.frameDt(0.016), 0.016);
      expect(Motion.frameDt(0.5), closeTo(1 / 60, 1e-12));
      expect(Motion.fallStep(0, 0.38), closeTo(1, 1e-12));
      expect(Motion.tumbleStep(0, 0.46), closeTo(1, 1e-12));
      expect(Motion.collapseStep(0, 0.7), closeTo(1, 1e-12));
      expect(Motion.cameraStep(0.9, 1), 1);
      expect(Motion.fallEase(0.5), 0.25);
      expect(Motion.swingOffset(0, 0.3), 0);
      expect(Motion.hookTilt(0), 0.045);
      expect(Motion.impactShake(held: true, multiplier: 3), 9);
      expect(Motion.impactShake(held: false, multiplier: 0), 14);
      expect(Motion.shakeDecay(0.1, 0.016), 0);
      expect(Motion.shoveX(0.1, 0), 0.72);
    });
  });
}
