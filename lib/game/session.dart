import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../config/cheat.dart';
import 'art.dart';
import 'rules.dart';

const int minBet = 10;

enum RoundPhase { betting, falling, live, busting, celebrating }

class Floor {
  const Floor({
    required this.art,
    required this.x,
    required this.width,
    required this.multiplier,
  });

  final int art;
  final double x;
  final double width;
  final double multiplier;
}

class Session extends ChangeNotifier {
  Session({
    required double balance,
    required double bet,
    required this.onBank,
    math.Random? random,
  }) : _rng = random ?? math.Random(),
       balance = balance < 0 ? 0 : balance {
    this.bet = _fitBet(bet);
    hanging = _rng.nextInt(blockAssets.length);
  }

  final void Function(double balance, double bet) onBank;
  final math.Random _rng;

  double balance;
  late double bet;
  RoundPhase phase = RoundPhase.betting;
  final List<Floor> floors = [];
  final List<double> results = [];
  late int hanging;
  int roundId = 0;
  double stake = 0;
  double payout = 0;
  double winAmount = 0;
  bool showPlaced = false;
  int beat = 0;

  bool get broke => balance < minBet;
  bool get betting => phase == RoundPhase.betting;
  bool get canCashOut => phase == RoundPhase.live && payout > 0;

  double get topX => floors.isEmpty ? 0 : floors.last.x;

  double get topWidth => floors.isEmpty ? foundationWidth : floors.last.width;

  double get swingSpeed {
    final heat = stake <= 0 ? 0.0 : (payout / stake - 1).clamp(0, 6);
    return 2.15 + floors.length * 0.28 + heat * 0.12;
  }

  double get swingReach => math.min(0.36, 0.26 + floors.length * 0.018);

  void nudgeBet(int direction) {
    if (!betting || broke) return;
    const step = 10.0;
    final units = bet / step;
    final next = direction > 0
        ? units.floor() * step + step
        : units.ceil() * step - step;
    bet = _fitBet(next);
    onBank(balance, bet);
    notifyListeners();
  }

  void doubleBet() {
    if (!betting || broke) return;
    bet = _fitBet(bet * 2);
    onBank(balance, bet);
    notifyListeners();
  }

  void allIn() {
    if (!betting || broke) return;
    bet = _money(balance);
    onBank(balance, bet);
    notifyListeners();
  }

  void refill() {
    balance = 100000;
    bet = 100;
    onBank(balance, bet);
    notifyListeners();
  }

  void grant(double amount) {
    if (!cheatsEnabled || !betting) return;
    balance = _money(balance + amount);
    bet = _fitBet(bet);
    onBank(balance, bet);
    notifyListeners();
  }

  void wipe() {
    if (!cheatsEnabled || !betting) return;
    balance = 0;
    bet = 0;
    onBank(balance, bet);
    notifyListeners();
  }

  bool armDrop() {
    if (phase == RoundPhase.falling ||
        phase == RoundPhase.busting ||
        phase == RoundPhase.celebrating) {
      return false;
    }
    if (phase == RoundPhase.betting) {
      if (broke || bet < minBet || bet > balance + 0.001) return false;
      stake = _money(bet);
      balance = _money(balance - stake);
      payout = stake;
      roundId = 100000000 + _rng.nextInt(900000000);
      showPlaced = true;
      onBank(balance, bet);
    }
    phase = RoundPhase.falling;
    beat++;
    notifyListeners();
    return true;
  }

  Landing settle(double x, double width, int art) {
    final landing = Cheat.apply(
      judgeLanding(
        blockX: x,
        blockWidth: width,
        topX: topX,
        topWidth: topWidth,
        roll: _rng.nextDouble(),
      ),
    );
    if (!landing.held) {
      phase = RoundPhase.busting;
      beat++;
      notifyListeners();
      return landing;
    }
    payout = growPayout(payout, landing.multiplier);
    floors.add(
      Floor(
        art: art,
        x: landing.center,
        width: width,
        multiplier: landing.multiplier,
      ),
    );
    results.add(landing.multiplier);
    hanging = _otherThan(art);
    phase = RoundPhase.live;
    beat++;
    notifyListeners();
    return landing;
  }

  void cashOut() {
    if (!canCashOut) return;
    winAmount = payout;
    balance = _money(balance + payout);
    if (bet > balance) bet = _fitBet(bet);
    hanging = _otherThan(floors.isEmpty ? hanging : floors.last.art);
    phase = RoundPhase.celebrating;
    onBank(balance, bet);
    beat++;
    notifyListeners();
  }

  void dismissPlaced() {
    if (!showPlaced) return;
    showPlaced = false;
    notifyListeners();
  }

  void backToBetting({required bool newPiece}) {
    floors.clear();
    results.clear();
    stake = 0;
    payout = 0;
    showPlaced = false;
    if (newPiece) hanging = _rng.nextInt(blockAssets.length);
    bet = _fitBet(bet);
    phase = RoundPhase.betting;
    beat++;
    notifyListeners();
  }

  int _otherThan(int art) {
    if (blockAssets.length < 2) return art;
    var next = _rng.nextInt(blockAssets.length - 1);
    if (next >= art) next++;
    return next;
  }

  double _fitBet(double value) {
    if (balance < minBet) return _money(balance);
    var next = value;
    if (next < minBet) next = minBet.toDouble();
    if (next > balance) next = balance;
    return _money(next);
  }

  double _money(double value) => (value * 100).roundToDouble() / 100;
}
