import '../game/motion.dart';
import '../game/rules.dart';

/// Store builds set this to false. The panel and every assist go with it.
const bool cheatsEnabled = false;

enum CheatAim { normal, lucky, miss }

class Cheat {
  static CheatAim aim = CheatAim.normal;

  static bool get lucky => cheatsEnabled && aim == CheatAim.lucky;

  static void toggleLucky() {
    if (!cheatsEnabled) return;
    aim = aim == CheatAim.lucky ? CheatAim.normal : CheatAim.lucky;
  }

  static void armMiss() {
    if (!cheatsEnabled) return;
    aim = CheatAim.miss;
  }

  static double? redirectedX(double swung, double topX) {
    if (!cheatsEnabled || aim == CheatAim.normal) return null;
    if (aim == CheatAim.lucky) return topX;
    return Motion.shoveX(swung, topX);
  }

  static Landing apply(Landing judged) {
    if (!cheatsEnabled || aim == CheatAim.normal) return judged;
    if (aim == CheatAim.miss) {
      aim = CheatAim.normal;
      return Landing.miss(judged.center);
    }
    return Landing.held(judged.center, topMultiplier);
  }
}
