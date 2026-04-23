import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/card.dart';
import '../models/deck.dart';
import '../models/hand_evaluator.dart';
import 'ai.dart';
import 'ai_personality.dart';
import 'player.dart';

/// 7-Card Stud streets.
///   3rd = 2 down + 1 up dealt; first bet round
///   4th = 1 up dealt; bet
///   5th = 1 up dealt; bet
///   6th = 1 up dealt; bet
///   7th = 1 down dealt; final bet, showdown
enum Street {
  thirdStreet,
  fourthStreet,
  fifthStreet,
  sixthStreet,
  seventhStreet,
  showdown,
  handComplete,
}

extension StreetX on Street {
  String get label => switch (this) {
        Street.thirdStreet => '3rd (쓰리카드)',
        Street.fourthStreet => '4th',
        Street.fifthStreet => '5th',
        Street.sixthStreet => '6th',
        Street.seventhStreet => '7th (히든)',
        Street.showdown => '쇼다운',
        Street.handComplete => '핸드 종료',
      };
}

enum ActionKind { fold, check, call, raise }

class PlayerAction {
  final ActionKind kind;
  final int amount;
  const PlayerAction._(this.kind, this.amount);
  const PlayerAction.fold() : this._(ActionKind.fold, 0);
  const PlayerAction.check() : this._(ActionKind.check, 0);
  const PlayerAction.call() : this._(ActionKind.call, 0);
  const PlayerAction.raise(int to) : this._(ActionKind.raise, to);
}

class Pot {
  final int amount;
  final List<Player> eligible;
  Pot(this.amount, this.eligible);
}

class ShowdownResult {
  final Player player;
  final HandRank rank;
  final int winnings;
  ShowdownResult(this.player, this.rank, this.winnings);
}

class GameEngine extends ChangeNotifier {
  final List<Player> players;
  final int ante;
  final int minBet;
  final PokerAI ai;
  final Duration aiDelay;
  final Duration turnDuration;
  final Duration countdownWarning;
  final int handsPerLevel;
  final double antePerLevelMultiplier;
  final void Function()? onDeal;
  final void Function()? onHumanTurn;
  final void Function(int newLevel, int newAnte)? onLevelUp;

  Deck _deck = Deck();
  int actorIdx = -1;
  int currentBet = 0;
  int lastRaiseSize = 0;
  Street street = Street.handComplete;
  final List<String> log = [];
  List<ShowdownResult> lastShowdown = [];
  Timer? _aiTimer;
  Timer? _turnTimer;
  DateTime? _turnDeadline;

  /// Tournament state
  int handNumber = 0;
  int tournamentLevel = 0;
  bool tournamentOver = false;
  Player? tournamentWinner;

  int get currentAnte => (ante * _anteMultiplier).round();

  double get _anteMultiplier {
    var m = 1.0;
    for (var i = 0; i < tournamentLevel; i++) {
      m *= antePerLevelMultiplier;
    }
    return m;
  }

  int get handsUntilNextLevel {
    final nextBoundary = (tournamentLevel + 1) * handsPerLevel;
    return nextBoundary - handNumber;
  }

  /// True while players may voluntarily claim "선" (opening action) at the
  /// start of 3rd street based on their own hand strength.
  bool declarationOpen = false;
  DateTime? _declarationDeadline;
  Timer? _declarationTimer;
  final List<Timer> _aiDeclareTimers = [];
  Player? declaredBy;
  static const Duration declarationWindow = Duration(seconds: 5);

  double get declarationSecondsRemaining {
    final d = _declarationDeadline;
    if (d == null) return 0;
    final ms = d.difference(DateTime.now()).inMilliseconds;
    return ms < 0 ? 0 : ms / 1000;
  }

  GameEngine({
    required this.players,
    this.ante = 10,
    this.minBet = 20,
    PokerAI? ai,
    this.aiDelay = const Duration(milliseconds: 900),
    this.turnDuration = const Duration(seconds: 20),
    this.countdownWarning = const Duration(seconds: 10),
    this.handsPerLevel = 5,
    this.antePerLevelMultiplier = 1.6,
    this.onDeal,
    this.onHumanTurn,
    this.onChipsToPot,
    this.onHumanWin,
    this.onLevelUp,
    this.onTournamentEnd,
    this.onPlayerAction,
  }) : ai = ai ?? PokerAI();

  /// Fired when a player's chips move to the pot
  /// (ante, call, bet, raise). The int is the amount contributed.
  final void Function(Player player, int amount)? onChipsToPot;

  /// Fired once after a hand ends if the human player won chips.
  final void Function()? onHumanWin;

  /// Fired when the last-standing player has been determined.
  final void Function(Player winner)? onTournamentEnd;

  /// Fired any time a player performs an action or declares 선. `tag` identifies
  /// the action bucket — used to pick a speech-bubble phrase:
  /// 'raise' | 'call' | 'check' | 'fold' | 'declare'.
  final void Function(Player player, String tag)? onPlayerAction;

  /// Seconds remaining on the current actor's clock. 0 when idle.
  double get turnSecondsRemaining {
    final d = _turnDeadline;
    if (d == null) return 0;
    final ms = d.difference(DateTime.now()).inMilliseconds;
    return ms < 0 ? 0 : ms / 1000;
  }

  /// True when the active player's remaining time is within the warning band.
  bool get showTurnCountdown {
    if (_turnDeadline == null) return false;
    return turnSecondsRemaining <= countdownWarning.inSeconds;
  }

  int get pot => players.fold(0, (sum, p) => sum + p.totalContributed);

  Player get currentActor => players[actorIdx];

  bool get awaitingHumanAction =>
      street != Street.handComplete &&
      street != Street.showdown &&
      actorIdx >= 0 &&
      players[actorIdx].isHuman &&
      players[actorIdx].canAct;

  int toCallFor(Player p) => (currentBet - p.currentBet).clamp(0, p.stack);

  int minRaiseTotal(Player p) {
    final minIncrement = lastRaiseSize == 0 ? minBet : lastRaiseSize;
    final minTotal = currentBet + minIncrement;
    if (minTotal > p.stack + p.currentBet) {
      return p.stack + p.currentBet;
    }
    // If no bet yet, the minimum "raise" is actually the opening bet.
    if (currentBet == 0) {
      final opening = minBet.clamp(1, p.stack + p.currentBet);
      return opening;
    }
    return minTotal;
  }

  int maxRaiseTotal(Player p) => p.stack + p.currentBet;

  /// True if the engine is in the pristine "no hand played yet" state.
  bool get isInitialState =>
      street == Street.handComplete &&
      lastShowdown.isEmpty &&
      players.every((p) =>
          p.totalContributed == 0 &&
          p.stack == p.initialStack &&
          p.status == PlayerStatus.active);

  /// Full reset: restore stacks, status, and clear transient state so the
  /// player can begin a fresh game.
  void resetGame() {
    _aiTimer?.cancel();
    _turnTimer?.cancel();
    _declarationTimer?.cancel();
    for (final t in _aiDeclareTimers) {
      t.cancel();
    }
    _aiDeclareTimers.clear();

    for (final p in players) {
      p.fullReset();
    }

    actorIdx = -1;
    currentBet = 0;
    lastRaiseSize = 0;
    street = Street.handComplete;
    lastShowdown = [];
    log.clear();
    declarationOpen = false;
    _declarationDeadline = null;
    declaredBy = null;
    _turnDeadline = null;
    handNumber = 0;
    tournamentLevel = 0;
    tournamentOver = false;
    tournamentWinner = null;

    notifyListeners();
  }

  void startHand() {
    _aiTimer?.cancel();
    _declarationTimer?.cancel();
    for (final t in _aiDeclareTimers) {
      t.cancel();
    }
    _aiDeclareTimers.clear();
    declarationOpen = false;
    _declarationDeadline = null;
    declaredBy = null;
    lastShowdown = [];
    log.clear();

    for (final p in players) {
      p.resetForHand();
    }

    final playing =
        players.where((p) => p.status == PlayerStatus.active).toList();
    if (playing.length < 2) {
      street = Street.handComplete;
      _emit('게임 종료');
      notifyListeners();
      return;
    }

    _deck = Deck();
    _deck.shuffle();

    // Tournament bookkeeping
    handNumber += 1;
    final newLevel = handNumber > 0 ? (handNumber - 1) ~/ handsPerLevel : 0;
    if (newLevel > tournamentLevel) {
      tournamentLevel = newLevel;
      _emit('레벨 $tournamentLevel — 앤티 $currentAnte');
      onLevelUp?.call(tournamentLevel, currentAnte);
    }

    final activeAnte = currentAnte;
    // Ante
    for (final p in players) {
      if (p.status != PlayerStatus.active) continue;
      final amt = activeAnte.clamp(0, p.stack);
      p.stack -= amt;
      p.totalContributed += amt;
      if (p.stack == 0) p.status = PlayerStatus.allIn;
      if (amt > 0) onChipsToPot?.call(p, amt);
    }
    _emit('[핸드 $handNumber · 레벨 $tournamentLevel] 앤티 $activeAnte');

    // 3rd street deal: 2 down + 1 up
    for (final p in players) {
      if (p.status != PlayerStatus.active && p.status != PlayerStatus.allIn) continue;
      p.downCards = [_deck.draw(), _deck.draw()];
      p.upCards = [_deck.draw()];
    }
    onDeal?.call();

    street = Street.thirdStreet;
    currentBet = 0;
    lastRaiseSize = 0;
    // Open a declaration window: any player may claim 선 based on their own
    // hand strength. First claimer becomes the first actor. If nobody claims
    // within the window, default order (highest door card) applies.
    _openDeclarationPhase();
  }

  void _openDeclarationPhase() {
    declarationOpen = true;
    declaredBy = null;
    _declarationDeadline = DateTime.now().add(declarationWindow);
    _emit('선 선언 창 열림 — ${declarationWindow.inSeconds}초');
    notifyListeners();

    _declarationTimer?.cancel();
    _declarationTimer = Timer(declarationWindow, () {
      if (!declarationOpen) return;
      _closeDeclarationPhase();
    });

    // Schedule AI declaration attempts based on each AI's hand strength.
    for (final t in _aiDeclareTimers) {
      t.cancel();
    }
    _aiDeclareTimers.clear();
    final rng = math.Random();
    for (final p in players) {
      if (p.isHuman || p.status != PlayerStatus.active) continue;
      final profile = AiPersonalityProfile.of(p.aiPersonality);
      final strength = ai.estimateStrength(p, const []) + profile.declareBoost;
      if (strength < 0.55) continue;
      final baseMs = 2600 - (strength * 1800).toInt();
      final jitter = rng.nextInt(500);
      _aiDeclareTimers.add(Timer(Duration(milliseconds: baseMs + jitter), () {
        if (!declarationOpen) return;
        _attemptDeclare(p);
      }));
    }
  }

  void declareHuman() {
    final human = players.firstWhere(
      (p) => p.isHuman,
      orElse: () => players.first,
    );
    _attemptDeclare(human);
  }

  void _attemptDeclare(Player p) {
    if (!declarationOpen) return;
    if (declaredBy != null) return;
    if (p.status != PlayerStatus.active) return;
    declaredBy = p;
    _emit('${p.name} 선 선언');
    onPlayerAction?.call(p, 'declare');
    _closeDeclarationPhase();
  }

  void _closeDeclarationPhase() {
    declarationOpen = false;
    _declarationDeadline = null;
    _declarationTimer?.cancel();
    _declarationTimer = null;
    for (final t in _aiDeclareTimers) {
      t.cancel();
    }
    _aiDeclareTimers.clear();

    if (declaredBy != null) {
      actorIdx = players.indexOf(declaredBy!);
      _emit('3rd street — ${players[actorIdx].name} (선언)');
    } else {
      actorIdx = _firstToActSeat();
      _emit('3rd street — ${players[actorIdx].name} (자동 선)');
    }
    notifyListeners();
    _beginActorTurn();
  }

  void submitAction(PlayerAction action) {
    if (street == Street.handComplete || street == Street.showdown) return;
    final p = players[actorIdx];
    if (!p.canAct) return;
    _cancelTurnTimer();
    _applyAction(p, action);
    _advance();
  }

  void _cancelTurnTimer() {
    _turnTimer?.cancel();
    _turnTimer = null;
    _turnDeadline = null;
  }

  void _beginActorTurn() {
    _cancelTurnTimer();
    if (actorIdx < 0) return;
    if (street == Street.handComplete || street == Street.showdown) return;
    final p = players[actorIdx];
    if (!p.canAct) return;
    _turnDeadline = DateTime.now().add(turnDuration);
    _turnTimer = Timer(turnDuration, _onTurnTimeout);
    if (p.isHuman) onHumanTurn?.call();
    _maybeScheduleAi();
  }

  void _onTurnTimeout() {
    if (actorIdx < 0) return;
    final p = players[actorIdx];
    if (!p.canAct) return;
    _emit('${p.name} 시간 초과 — 폴드');
    submitAction(const PlayerAction.fold());
  }

  void _applyAction(Player p, PlayerAction action) {
    // 3rd 스트리트에서는 폴드 금지 — 자동으로 체크 또는 콜로 전환.
    var effective = action;
    if (effective.kind == ActionKind.fold && street == Street.thirdStreet) {
      final call = toCallFor(p);
      effective = call == 0
          ? const PlayerAction.check()
          : const PlayerAction.call();
    }
    p.hasActedThisRound = true;
    switch (effective.kind) {
      case ActionKind.fold:
        p.status = PlayerStatus.folded;
        _emit('${p.name} 폴드');
        onPlayerAction?.call(p, 'fold');
      case ActionKind.check:
        _emit('${p.name} 체크');
        onPlayerAction?.call(p, 'check');
      case ActionKind.call:
        final call = toCallFor(p);
        _moveChips(p, call);
        if (p.stack == 0) {
          p.status = PlayerStatus.allIn;
          _emit('${p.name} 콜 올인 ($call)');
        } else {
          _emit('${p.name} 콜 ($call)');
        }
        onPlayerAction?.call(p, 'call');
      case ActionKind.raise:
        final target =
            effective.amount.clamp(minRaiseTotal(p), maxRaiseTotal(p));
        final increment = target - p.currentBet;
        final raiseAboveCurrent = target - currentBet;
        _moveChips(p, increment);
        if (raiseAboveCurrent > 0) {
          lastRaiseSize = raiseAboveCurrent;
        }
        final wasOpeningBet = currentBet == 0;
        currentBet = target;
        if (p.stack == 0) {
          p.status = PlayerStatus.allIn;
          _emit(wasOpeningBet
              ? '${p.name} 벳 올인 $target'
              : '${p.name} 레이즈 올인 to $target');
        } else {
          _emit(wasOpeningBet
              ? '${p.name} 벳 $target'
              : '${p.name} 레이즈 to $target');
        }
        onPlayerAction?.call(p, 'raise');
        for (final other in players) {
          if (other != p && other.status == PlayerStatus.active) {
            other.hasActedThisRound = false;
          }
        }
    }
  }

  void _moveChips(Player p, int amount) {
    final actual = amount.clamp(0, p.stack);
    p.stack -= actual;
    p.currentBet += actual;
    p.totalContributed += actual;
    if (actual > 0) onChipsToPot?.call(p, actual);
  }

  void _advance() {
    final remaining = players.where((p) => p.inHand).toList();
    if (remaining.length == 1) {
      _awardPotsToLastStanding(remaining.first);
      return;
    }

    if (_bettingRoundComplete()) {
      _nextStreet();
      return;
    }

    final next = _nextActorSeat(actorIdx);
    if (next == null) {
      _nextStreet();
      return;
    }
    actorIdx = next;
    notifyListeners();
    _beginActorTurn();
  }

  bool _bettingRoundComplete() {
    final actives =
        players.where((p) => p.status == PlayerStatus.active).toList();
    if (actives.isEmpty) return true;
    for (final p in actives) {
      if (!p.hasActedThisRound) return false;
      if (p.currentBet != currentBet) return false;
    }
    return true;
  }

  int? _nextActorSeat(int from) {
    for (var i = 1; i <= players.length; i++) {
      final idx = (from + i) % players.length;
      final p = players[idx];
      if (p.status == PlayerStatus.active &&
          (!p.hasActedThisRound || p.currentBet < currentBet)) {
        return idx;
      }
    }
    return null;
  }

  void _nextStreet() {
    for (final p in players) {
      p.resetForBettingRound();
    }
    currentBet = 0;
    lastRaiseSize = 0;

    switch (street) {
      case Street.thirdStreet:
        _dealOneUpEach();
        street = Street.fourthStreet;
        _emit('--- 4th street ---');
        onDeal?.call();
      case Street.fourthStreet:
        _dealOneUpEach();
        street = Street.fifthStreet;
        _emit('--- 5th street ---');
        onDeal?.call();
      case Street.fifthStreet:
        _dealOneUpEach();
        street = Street.sixthStreet;
        _emit('--- 6th street ---');
        onDeal?.call();
      case Street.sixthStreet:
        _dealOneDownEach();
        street = Street.seventhStreet;
        _emit('--- 7th street (히든) ---');
        onDeal?.call();
      case Street.seventhStreet:
        street = Street.showdown;
        _showdown();
        return;
      case Street.showdown:
      case Street.handComplete:
        return;
    }

    final canAct =
        players.where((p) => p.status == PlayerStatus.active).toList();
    if (canAct.length <= 1) {
      Future.delayed(aiDelay, () {
        if (street != Street.handComplete && street != Street.showdown) {
          _nextStreet();
        }
      });
      notifyListeners();
      return;
    }

    actorIdx = _firstToActSeat();
    notifyListeners();
    _beginActorTurn();
  }

  void _dealOneUpEach() {
    for (final p in players) {
      if (!p.inHand) continue;
      p.upCards = [...p.upCards, _deck.draw()];
    }
  }

  void _dealOneDownEach() {
    for (final p in players) {
      if (!p.inHand) continue;
      p.downCards = [...p.downCards, _deck.draw()];
    }
  }

  /// On 3rd street, highest door card acts first. On 4th+ streets,
  /// highest exposed hand acts first. Folded/out players are skipped.
  int _firstToActSeat() {
    final candidates = <int>[
      for (var i = 0; i < players.length; i++)
        if (players[i].status == PlayerStatus.active) i,
    ];
    if (candidates.isEmpty) return -1;
    candidates.sort((a, b) =>
        _compareExposed(players[b].upCards, players[a].upCards));
    return candidates.first;
  }

  /// Positive if a is stronger visible hand than b.
  int _compareExposed(List<PlayingCard> a, List<PlayingCard> b) {
    final ra = _visibleRank(a);
    final rb = _visibleRank(b);
    for (var i = 0; i < ra.length && i < rb.length; i++) {
      final d = ra[i].compareTo(rb[i]);
      if (d != 0) return d;
    }
    // Suit tiebreak on the single door card.
    if (a.isNotEmpty && b.isNotEmpty) {
      return _suitRank(a.first.suit).compareTo(_suitRank(b.first.suit));
    }
    return 0;
  }

  List<int> _visibleRank(List<PlayingCard> up) {
    if (up.isEmpty) return [0];
    // Group by count of same rank.
    final counts = <int, int>{};
    for (final c in up) {
      counts[c.rank.value] = (counts[c.rank.value] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final c = b.value.compareTo(a.value);
        if (c != 0) return c;
        return b.key.compareTo(a.key);
      });
    return [
      entries.first.value, // biggest group size (4,3,2,1)
      for (final e in entries) e.key,
    ];
  }

  int _suitRank(Suit s) => switch (s) {
        Suit.spades => 4,
        Suit.hearts => 3,
        Suit.diamonds => 2,
        Suit.clubs => 1,
      };

  void _showdown() {
    final contenders = players.where((p) => p.inHand).toList();
    if (contenders.isEmpty) {
      street = Street.handComplete;
      notifyListeners();
      return;
    }

    final ranks = <Player, HandRank>{
      for (final p in contenders) p: HandEvaluator.evaluate(p.allCards),
    };

    final pots = _buildPots();
    final winnings = <Player, int>{for (final p in contenders) p: 0};

    for (final pot in pots) {
      final eligible = pot.eligible.where((p) => p.inHand).toList();
      if (eligible.isEmpty) continue;
      eligible.sort((a, b) => ranks[b]!.compareTo(ranks[a]!));
      final top = ranks[eligible.first]!;
      final winners =
          eligible.where((p) => ranks[p]!.compareTo(top) == 0).toList();
      final share = pot.amount ~/ winners.length;
      final remainder = pot.amount - share * winners.length;
      for (final w in winners) {
        winnings[w] = (winnings[w] ?? 0) + share;
      }
      if (remainder > 0 && winners.isNotEmpty) {
        winnings[winners.first] = (winnings[winners.first] ?? 0) + remainder;
      }
    }

    winnings.forEach((p, amt) {
      p.stack += amt;
    });

    lastShowdown = [
      for (final p in contenders)
        ShowdownResult(p, ranks[p]!, winnings[p] ?? 0)
    ]..sort((a, b) => b.rank.compareTo(a.rank));

    for (final r in lastShowdown) {
      _emit('${r.player.name}: ${r.rank.detailedLabel}'
          '${r.winnings > 0 ? '  → +${r.winnings}' : ''}');
    }

    street = Street.handComplete;
    _maybeFireHumanWin();
    _checkTournamentEnd();
    notifyListeners();
  }

  void _awardPotsToLastStanding(Player winner) {
    final total = pot;
    winner.stack += total;
    lastShowdown = [
      ShowdownResult(
        winner,
        const HandRank(
          category: HandCategory.highCard,
          tiebreakers: [],
          bestFive: [],
        ),
        total,
      )
    ];
    _emit('${winner.name} 승리 (+$total) — 나머지 전원 폴드');
    street = Street.handComplete;
    _maybeFireHumanWin();
    _checkTournamentEnd();
    notifyListeners();
  }

  void _maybeFireHumanWin() {
    final humanWon = lastShowdown.any(
      (r) => r.player.isHuman && r.winnings > 0,
    );
    if (humanWon) onHumanWin?.call();
  }

  void _checkTournamentEnd() {
    if (tournamentOver) return;
    final solvent = players.where((p) => p.stack > 0).toList();
    if (solvent.length <= 1) {
      tournamentOver = true;
      tournamentWinner = solvent.isEmpty ? null : solvent.first;
      if (tournamentWinner != null) {
        _emit('🏆 토너먼트 종료 — 우승: ${tournamentWinner!.name}');
        onTournamentEnd?.call(tournamentWinner!);
      }
    }
  }

  List<Pot> _buildPots() {
    final contributions = {
      for (final p in players) p: p.totalContributed,
    }..removeWhere((_, v) => v == 0);

    final pots = <Pot>[];
    while (contributions.isNotEmpty) {
      final floor = contributions.values.reduce((a, b) => a < b ? a : b);
      final participants = contributions.keys.toList();
      final amount = floor * participants.length;
      pots.add(Pot(amount, participants));
      contributions.updateAll((p, v) => v - floor);
      contributions.removeWhere((_, v) => v == 0);
    }
    return pots;
  }

  void _maybeScheduleAi() {
    if (street == Street.handComplete || street == Street.showdown) return;
    if (actorIdx < 0) return;
    final p = players[actorIdx];
    if (p.isHuman || !p.canAct) return;
    _aiTimer?.cancel();
    _aiTimer = Timer(aiDelay, () {
      if (street == Street.handComplete || street == Street.showdown) return;
      if (actorIdx < 0) return;
      final current = players[actorIdx];
      if (current != p || !p.canAct) return;
      final opponentsUp = [
        for (final o in players)
          if (o != p && o.inHand) ...o.upCards,
      ];
      final action = ai.decide(
        me: p,
        opponentsUp: opponentsUp,
        currentBet: currentBet,
        minRaise: minRaiseTotal(p),
        maxRaise: maxRaiseTotal(p),
        pot: pot,
      );
      submitAction(action);
    });
  }

  void _emit(String msg) {
    log.add(msg);
    if (log.length > 120) log.removeAt(0);
  }

  @override
  void dispose() {
    _aiTimer?.cancel();
    _turnTimer?.cancel();
    _declarationTimer?.cancel();
    for (final t in _aiDeclareTimers) {
      t.cancel();
    }
    super.dispose();
  }
}
