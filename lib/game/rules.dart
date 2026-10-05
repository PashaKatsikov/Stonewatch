const double foundationWidth = 0.37;
const double minCoefficient = 0.4;
const double missRatio = 0.38;

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
  final overlap = _overlap(blockX, blockWidth, topX, topWidth);
  final ratio = blockWidth <= 0 ? 0.0 : overlap / blockWidth;
  if (ratio < missRatio) return Landing.miss(blockX);
  return Landing.held(blockX, multiplierForRatio(ratio, roll));
}

double multiplierForRatio(double ratio, double roll) {
  const bands = <(double, List<double>)>[
    (0.50, [0.4, 0.45, 0.5]),
    (0.63, [0.8, 1.0, 1.1]),
    (0.75, [1.25, 1.5, 1.85]),
    (0.86, [2.0, 2.5, 2.9]),
    (0.94, [3.5, 5.0, 8.0]),
    (2, [10, 15, 25]),
  ];
  final t = roll.clamp(0.0, 0.999);
  for (final band in bands) {
    if (ratio < band.$1) {
      final list = band.$2;
      return list[(t * list.length).floor()];
    }
  }
  return bands.last.$2.last;
}

double growPayout(double payout, double multiplier) {
  return (payout * multiplier * 100).roundToDouble() / 100;
}

double _overlap(double ax, double aw, double bx, double bw) {
  final left = ax - aw / 2;
  final right = ax + aw / 2;
  final topL = bx - bw / 2;
  final topR = bx + bw / 2;
  final hit = _min(right, topR) - _max(left, topL);
  return hit > 0 ? hit : 0;
}

double _min(double a, double b) => a < b ? a : b;
double _max(double a, double b) => a > b ? a : b;
