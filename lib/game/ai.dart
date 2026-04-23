import 'dart:math';

import '../models/card.dart';
import '../models/hand_evaluator.dart';
import 'ai_personality.dart';
import 'game_engine.dart';
import 'player.dart';

/// Simple rule-based AI for 7-Card Stud. Uses best-5 evaluation when it has
/// ≥5 cards, otherwise a heuristic on pairs/high-cards/flush+straight draws.
/// Each call can be parameterised by the player's [AiPersonality] so each
/// opponent plays noticeably differently.
class PokerAI {
  final Random _rng;
  PokerAI({int? seed}) : _rng = Random(seed);

  PlayerAction decide({
    required Player me,
    required List<PlayingCard> opponentsUp,
    required int currentBet,
    required int minRaise,
    required int maxRaise,
    required int pot,
  }) {
    final profile = AiPersonalityProfile.of(me.aiPersonality);
    final toCall = (currentBet - me.currentBet).clamp(0, me.stack);
    final baseStrength = _estimate(me.allCards, opponentsUp);

    final jitter = _rng.nextDouble() * profile.jitter * 2 - profile.jitter;
    final adjusted =
        (baseStrength + profile.confidenceBias + jitter).clamp(0.0, 1.0);

    if (toCall == 0) {
      if (adjusted > profile.raiseThreshold && maxRaise >= minRaise) {
        return PlayerAction.raise(_sizeBet(
          pot,
          minRaise,
          maxRaise,
          adjusted,
          profile.betSizeMultiplier,
        ));
      }
      return const PlayerAction.check();
    }

    final potOdds = toCall / (pot + toCall);
    final foldThreshold = 0.18 + profile.foldBias;
    if (adjusted < foldThreshold && toCall > me.stack * 0.05) {
      return const PlayerAction.fold();
    }
    final strongThreshold = 0.80 - profile.confidenceBias * 0.3;
    if (adjusted > strongThreshold &&
        me.stack > toCall &&
        maxRaise > currentBet) {
      final raise = _sizeBet(
        pot,
        minRaise,
        maxRaise,
        adjusted,
        profile.betSizeMultiplier,
      );
      if (raise > currentBet) return PlayerAction.raise(raise);
    }
    if (adjusted >= potOdds - 0.05 + profile.foldBias * 0.5) {
      return const PlayerAction.call();
    }
    return const PlayerAction.fold();
  }

  int _sizeBet(
    int pot,
    int minRaise,
    int maxRaise,
    double strength,
    double sizeMul,
  ) {
    if (maxRaise <= minRaise) return minRaise;
    final target = (pot * (0.4 + strength * 0.7) * sizeMul).round();
    return target.clamp(minRaise, maxRaise);
  }

  /// Public strength estimate for a player (their own cards) against an
  /// optional set of visible opponent cards. Returns [0..1].
  double estimateStrength(Player p, List<PlayingCard> opponentsUp) =>
      _estimate(p.allCards, opponentsUp);

  double _estimate(List<PlayingCard> mine, List<PlayingCard> oppUp) {
    if (mine.length >= 5) {
      final rank = HandEvaluator.evaluate(mine);
      var base = switch (rank.category) {
        HandCategory.highCard => 0.15,
        HandCategory.onePair => 0.4,
        HandCategory.twoPair => 0.6,
        HandCategory.threeOfAKind => 0.78,
        HandCategory.straight => 0.85,
        HandCategory.flush => 0.88,
        HandCategory.fullHouse => 0.94,
        HandCategory.fourOfAKind => 0.98,
        HandCategory.straightFlush => 0.99,
      };
      if (rank.category == HandCategory.highCard ||
          rank.category == HandCategory.onePair) {
        final high = rank.tiebreakers.first;
        base = (base + (high - 2) / 120).clamp(0.0, 1.0);
      }
      return base;
    }
    return _shortScore(mine);
  }

  /// Heuristic for 3–4 cards: group counts + high-card bonus + draw potential.
  double _shortScore(List<PlayingCard> cards) {
    if (cards.isEmpty) return 0.0;
    final counts = <int, int>{};
    for (final c in cards) {
      counts[c.rank.value] = (counts[c.rank.value] ?? 0) + 1;
    }
    final groups = counts.values.toList()..sort((a, b) => b.compareTo(a));
    final top = groups.first;

    double base;
    if (top >= 4) {
      base = 0.95;
    } else if (top == 3) {
      final tripRank = counts.entries.firstWhere((e) => e.value == 3).key;
      base = 0.7 + (tripRank - 2) / 60;
    } else if (top == 2) {
      final pairEntries = counts.entries.where((e) => e.value == 2).toList();
      if (pairEntries.length >= 2) {
        // two pair
        final top2 = pairEntries.map((e) => e.key).toList()
          ..sort((a, b) => b.compareTo(a));
        base = 0.55 + (top2.first - 2) / 80;
      } else {
        final pairRank = pairEntries.first.key;
        base = 0.3 + (pairRank - 2) / 40;
      }
    } else {
      final highest = counts.keys.reduce((a, b) => a > b ? a : b);
      base = 0.05 + (highest - 2) / 60;
    }

    // Flush draw bonus
    final suitCounts = <Suit, int>{};
    for (final c in cards) {
      suitCounts[c.suit] = (suitCounts[c.suit] ?? 0) + 1;
    }
    final maxSuit = suitCounts.values.reduce((a, b) => a > b ? a : b);
    if (maxSuit >= 4) {
      base += 0.2;
    } else if (maxSuit == 3 && cards.length <= 4) {
      base += 0.08;
    }

    // Straight draw bonus (rough)
    final uniqueRanks = counts.keys.toList()..sort();
    if (uniqueRanks.length >= 3) {
      final span = uniqueRanks.last - uniqueRanks.first;
      if (span <= 4 && uniqueRanks.length >= 4) {
        base += 0.15;
      } else if (span <= 4 && uniqueRanks.length == 3) {
        base += 0.05;
      }
    }

    return base.clamp(0.0, 1.0);
  }
}
