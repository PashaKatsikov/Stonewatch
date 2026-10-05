import 'package:flutter_test/flutter_test.dart';
import 'package:stonewatch/config/cheat.dart';
import 'package:stonewatch/format.dart';
import 'package:stonewatch/game/rules.dart';

void main() {
  test('a centered drop holds and pays more than an edge', () {
    final clean = judgeLanding(
      blockX: 0,
      blockWidth: 0.32,
      topX: 0,
      topWidth: foundationWidth,
      roll: 0,
    );
    final sloppy = judgeLanding(
      blockX: 0.11,
      blockWidth: 0.36,
      topX: 0,
      topWidth: 0.36,
      roll: 0,
    );
    expect(clean.held, isTrue);
    expect(sloppy.held, isTrue);
    expect(clean.multiplier, greaterThan(sloppy.multiplier));
    expect(sloppy.multiplier, greaterThanOrEqualTo(minCoefficient));
  });

  test('a drop that clears the roof is a miss', () {
    final landing = judgeLanding(
      blockX: 0.36,
      blockWidth: 0.30,
      topX: 0,
      topWidth: 0.30,
      roll: 0.2,
    );
    expect(landing.held, isFalse);
    expect(landing.multiplier, 0);
  });

  test('payout is the running product rounded to cents', () {
    var payout = 100.0;
    for (final mult in [1.1, 2.9, 1.25, 1.0]) {
      payout = growPayout(payout, mult);
    }
    expect(payout, 398.75);
    expect(growPayout(398.75, 1.25), 498.44);
  });

  test('assists do nothing while the store flag is off', () {
    Cheat.aim = CheatAim.lucky;
    final judged = Cheat.apply(const Landing.held(0.1, 1.25));
    expect(judged.multiplier, 1.25);
    expect(Cheat.redirectedX(0.2, 0), isNull);

    Cheat.armMiss();
    expect(Cheat.aim, CheatAim.lucky);
  });

  test('amounts and coefficients match the table style', () {
    expect(formatAmount(100000), '100 000');
    expect(formatAmount(100298.43), '100 298.43');
    expect(formatAmount(66.6), '66.6');
    expect(formatAmount(185), '185');
    expect(formatMult(1.85), 'x1.85');
    expect(formatMult(1), 'x1');
    expect(formatMult(0.4), 'x0.4');
    expect(formatMult(0), 'x0');
  });
}
