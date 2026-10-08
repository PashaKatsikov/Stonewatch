// Bindings to the Rust crate in native/stonewatch_core, bundled by
// hook/build.dart. The stateless math is reached through one opaque
// dispatcher keyed by a selector; dice keeps a few short exports.
// Keep the selectors and symbols in sync with
// native/stonewatch_core/src/ffi.rs.
@DefaultAsset('package:stonewatch/stonewatch_core')
library;

import 'dart:ffi';

// ── dispatcher ───────────────────────────────────────────────────────

@Native<Double Function(Uint32, Double, Double, Double, Double, Double)>(
  symbol: 'o9c',
  isLeaf: true,
)
external double _m(int sel, double a, double b, double c, double d, double e);

// Selector table (mirrors the match in ffi.rs).
const int _kFoundationWidth = 1;
const int _kMinCoefficient = 2;
const int _kMissRatio = 3;
const int _kTopMultiplier = 4;
const int _kJudgeLanding = 5;
const int _kMultiplierForRatio = 6;
const int _kGrowPayout = 7;
const int _kMinBet = 8;
const int _kStartingBalance = 9;
const int _kStartingBet = 10;
const int _kMoney = 11;
const int _kOpeningBalance = 12;
const int _kIsBroke = 13;
const int _kFitBet = 14;
const int _kNudgeBet = 15;
const int _kDoubleBet = 16;
const int _kCanPlace = 17;
const int _kDebit = 18;
const int _kCredit = 19;
const int _kFrameDt = 20;
const int _kSwingSpeed = 21;
const int _kSwingReach = 22;
const int _kSwingAdvance = 23;
const int _kSwingOffset = 24;
const int _kHookTilt = 25;
const int _kFallStep = 26;
const int _kTumbleStep = 27;
const int _kCollapseStep = 28;
const int _kCameraStep = 29;
const int _kFallEase = 30;
const int _kTumbleSlide = 31;
const int _kTumbleDrop = 32;
const int _kTumbleSpin = 33;
const int _kCollapseSink = 34;
const int _kMissDirection = 35;
const int _kImpactShake = 36;
const int _kShakeDecay = 37;
const int _kShakeOffset = 38;
const int _kShoveX = 39;

// ── rules ────────────────────────────────────────────────────────────

double swFoundationWidth() => _m(_kFoundationWidth, 0, 0, 0, 0, 0);

double swMinCoefficient() => _m(_kMinCoefficient, 0, 0, 0, 0, 0);

double swMissRatio() => _m(_kMissRatio, 0, 0, 0, 0, 0);

double swTopMultiplier() => _m(_kTopMultiplier, 0, 0, 0, 0, 0);

double swJudgeLanding(
  double blockX,
  double blockWidth,
  double topX,
  double topWidth,
  double roll,
) => _m(_kJudgeLanding, blockX, blockWidth, topX, topWidth, roll);

double swMultiplierForRatio(double ratio, double roll) =>
    _m(_kMultiplierForRatio, ratio, roll, 0, 0, 0);

double swGrowPayout(double payout, double multiplier) =>
    _m(_kGrowPayout, payout, multiplier, 0, 0, 0);

// ── economy ──────────────────────────────────────────────────────────

double swMinBet() => _m(_kMinBet, 0, 0, 0, 0, 0);

double swStartingBalance() => _m(_kStartingBalance, 0, 0, 0, 0, 0);

double swStartingBet() => _m(_kStartingBet, 0, 0, 0, 0, 0);

double swMoney(double value) => _m(_kMoney, value, 0, 0, 0, 0);

double swOpeningBalance(double value) => _m(_kOpeningBalance, value, 0, 0, 0, 0);

bool swIsBroke(double balance) => _m(_kIsBroke, balance, 0, 0, 0, 0) != 0;

double swFitBet(double value, double balance) =>
    _m(_kFitBet, value, balance, 0, 0, 0);

double swNudgeBet(double bet, int direction, double balance) =>
    _m(_kNudgeBet, bet, direction.toDouble(), balance, 0, 0);

double swDoubleBet(double bet, double balance) =>
    _m(_kDoubleBet, bet, balance, 0, 0, 0);

bool swCanPlace(double bet, double balance) =>
    _m(_kCanPlace, bet, balance, 0, 0, 0) != 0;

double swDebit(double balance, double amount) =>
    _m(_kDebit, balance, amount, 0, 0, 0);

double swCredit(double balance, double amount) =>
    _m(_kCredit, balance, amount, 0, 0, 0);

// ── motion ───────────────────────────────────────────────────────────

double swFrameDt(double raw) => _m(_kFrameDt, raw, 0, 0, 0, 0);

double swSwingSpeed(double stake, double payout, int floors) =>
    _m(_kSwingSpeed, stake, payout, floors.toDouble(), 0, 0);

double swSwingReach(int floors) =>
    _m(_kSwingReach, floors.toDouble(), 0, 0, 0, 0);

double swSwingAdvance(double phase, double dt, double speed) =>
    _m(_kSwingAdvance, phase, dt, speed, 0, 0);

double swSwingOffset(double phase, double reach) =>
    _m(_kSwingOffset, phase, reach, 0, 0, 0);

double swHookTilt(double phase) => _m(_kHookTilt, phase, 0, 0, 0, 0);

double swFallStep(double t, double dt) => _m(_kFallStep, t, dt, 0, 0, 0);

double swTumbleStep(double t, double dt) => _m(_kTumbleStep, t, dt, 0, 0, 0);

double swCollapseStep(double t, double dt) =>
    _m(_kCollapseStep, t, dt, 0, 0, 0);

double swCameraStep(double t, double dt) => _m(_kCameraStep, t, dt, 0, 0, 0);

double swFallEase(double t) => _m(_kFallEase, t, 0, 0, 0, 0);

double swTumbleSlide(double direction, double t) =>
    _m(_kTumbleSlide, direction, t, 0, 0, 0);

double swTumbleDrop(double t) => _m(_kTumbleDrop, t, 0, 0, 0, 0);

double swTumbleSpin(double direction, double t) =>
    _m(_kTumbleSpin, direction, t, 0, 0, 0);

double swCollapseSink(double amount) => _m(_kCollapseSink, amount, 0, 0, 0, 0);

double swMissDirection(double blockX, double topX) =>
    _m(_kMissDirection, blockX, topX, 0, 0, 0);

double swImpactShake(bool held, double multiplier) =>
    _m(_kImpactShake, held ? 1 : 0, multiplier, 0, 0, 0);

double swShakeDecay(double shake, double dt) =>
    _m(_kShakeDecay, shake, dt, 0, 0, 0);

double swShakeOffset(double clock, double shake) =>
    _m(_kShakeOffset, clock, shake, 0, 0, 0);

double swShoveX(double swung, double topX) =>
    _m(_kShoveX, swung, topX, 0, 0, 0);

// ── dice ─────────────────────────────────────────────────────────────

@Native<Pointer<Void> Function(Uint64)>(symbol: 'o1k', isLeaf: true)
external Pointer<Void> swDiceNew(int seed);

@Native<Void Function(Pointer<Void>)>(symbol: 'o1x', isLeaf: true)
external void swDiceFree(Pointer<Void> handle);

@Native<Double Function(Pointer<Void>)>(symbol: 'o2u', isLeaf: true)
external double swDiceUnit(Pointer<Void> handle);

@Native<Uint32 Function(Pointer<Void>, Uint32)>(symbol: 'o2b', isLeaf: true)
external int swDiceBelow(Pointer<Void> handle, int n);

@Native<Uint32 Function(Pointer<Void>)>(symbol: 'o2r', isLeaf: true)
external int swDiceRoundId(Pointer<Void> handle);

@Native<Uint32 Function(Pointer<Void>, Uint32, Uint32)>(
  symbol: 'o2o',
  isLeaf: true,
)
external int swDiceOtherThan(Pointer<Void> handle, int art, int count);
