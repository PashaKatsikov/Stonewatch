import '../core/stonewatch_core.dart';

/// Swing, fall, tumble and shake kinematics computed by the Rust core.
/// Horizontal results are fractions of the stage width measured from the
/// centre; vertical drops are fractions of the stage height.
abstract final class Motion {
  static double frameDt(double raw) => swFrameDt(raw);

  static double swingAdvance(double phase, double dt, double speed) =>
      swSwingAdvance(phase, dt, speed);

  static double swingOffset(double phase, double reach) =>
      swSwingOffset(phase, reach);

  static double hookTilt(double phase) => swHookTilt(phase);

  static double fallStep(double t, double dt) => swFallStep(t, dt);

  static double tumbleStep(double t, double dt) => swTumbleStep(t, dt);

  static double collapseStep(double t, double dt) => swCollapseStep(t, dt);

  static double cameraStep(double t, double dt) => swCameraStep(t, dt);

  static double fallEase(double t) => swFallEase(t);

  static double tumbleSlide(double direction, double t) =>
      swTumbleSlide(direction, t);

  static double tumbleDrop(double t) => swTumbleDrop(t);

  static double tumbleSpin(double direction, double t) =>
      swTumbleSpin(direction, t);

  static double collapseSink(double amount) => swCollapseSink(amount);

  static double missDirection(double blockX, double topX) =>
      swMissDirection(blockX, topX);

  static double impactShake({required bool held, required double multiplier}) =>
      swImpactShake(held, multiplier);

  static double shakeDecay(double shake, double dt) => swShakeDecay(shake, dt);

  static double shakeOffset(double clock, double shake) =>
      swShakeOffset(clock, shake);

  static double shoveX(double swung, double topX) => swShoveX(swung, topX);
}
