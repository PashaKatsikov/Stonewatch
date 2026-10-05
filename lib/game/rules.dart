import '../core/stonewatch_core.dart';

final double foundationWidth = swFoundationWidth();
final double minCoefficient = swMinCoefficient();
final double missRatio = swMissRatio();
final double topMultiplier = swTopMultiplier();

class Landing {
  const Landing.held(this.center, this.multiplier) : held = true;
  const Landing.miss(this.center) : held = false, multiplier = 0;

  final bool held;
  final double center;
  final double multiplier;
}

Landing judgeLanding({
  required double blockX,
  required double blockWidth,
  required double topX,
  required double topWidth,
  required double roll,
}) {
  final multiplier = swJudgeLanding(blockX, blockWidth, topX, topWidth, roll);
  if (multiplier <= 0) return Landing.miss(blockX);
  return Landing.held(blockX, multiplier);
}

double multiplierForRatio(double ratio, double roll) =>
    swMultiplierForRatio(ratio, roll);

double growPayout(double payout, double multiplier) =>
    swGrowPayout(payout, multiplier);
