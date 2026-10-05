import 'package:flutter/foundation.dart';

import '../config/cheat.dart';
import '../core/stonewatch_core.dart';
import 'art.dart';
import 'dice.dart';
import 'rules.dart';

final int minBet = swMinBet().round();
final double startingBalance = swStartingBalance();
final double startingBet = swStartingBet();

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
    int? seed,
  }) : _dice = Dice(seed),
       balance = swOpeningBalance(balance) {
    this.bet = swFitBet(bet, this.balance);
    hanging = _dice.below(blockAssets.length);
  }

  final void Function(double balance, double bet) onBank;
  final Dice _dice;

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

  bool get broke => swIsBroke(balance);
  bool get betting => phase == RoundPhase.betting;
  bool get canCashOut => phase == RoundPhase.live && payout > 0;

  double get topX => floors.isEmpty ? 0 : floors.last.x;

  double get topWidth => floors.isEmpty ? foundationWidth : floors.last.width;

  double get swingSpeed => swSwingSpeed(stake, payout, floors.length);

  double get swingReach => swSwingReach(floors.length);

  void nudgeBet(int direction) {
    if (!betting || broke) return;
    bet = swNudgeBet(bet, direction, balance);
    onBank(balance, bet);
    notifyListeners();
  }

  void doubleBet() {
    if (!betting || broke) return;
    bet = swDoubleBet(bet, balance);
    onBank(balance, bet);
    notifyListeners();
  }

  void allIn() {
    if (!betting || broke) return;
    bet = swMoney(balance);
    onBank(balance, bet);
    notifyListeners();
  }

  void refill() {
    balance = startingBalance;
    bet = startingBet;
    onBank(balance, bet);
    notifyListeners();
  }

  void grant(double amount) {
    if (!cheatsEnabled || !betting) return;
    balance = swCredit(balance, amount);
    bet = swFitBet(bet, balance);
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
      if (!swCanPlace(bet, balance)) return false;
      stake = swMoney(bet);
      balance = swDebit(balance, stake);
      payout = stake;
      roundId = _dice.roundId();
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
        roll: _dice.unit(),
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
    hanging = _dice.otherThan(art, blockAssets.length);
    phase = RoundPhase.live;
    beat++;
    notifyListeners();
    return landing;
  }

  void cashOut() {
    if (!canCashOut) return;
    winAmount = payout;
    balance = swCredit(balance, payout);
    if (bet > balance) bet = swFitBet(bet, balance);
    hanging = _dice.otherThan(
      floors.isEmpty ? hanging : floors.last.art,
      blockAssets.length,
    );
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
    if (newPiece) hanging = _dice.below(blockAssets.length);
    bet = swFitBet(bet, balance);
    phase = RoundPhase.betting;
    beat++;
    notifyListeners();
  }

  @override
  void dispose() {
    _dice.close();
    super.dispose();
  }
}
