import 'dart:convert';

import '../models/hand_evaluator.dart';
import 'stats_store.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  const Achievement(this.id, this.title, this.description);
}

class Achievements {
  Achievements._();
  static const firstWin = Achievement('first_win', '첫 승리', '첫 핸드에서 팟을 차지했습니다');
  static const firstPair = Achievement('first_pair', '원 페어', '원 페어로 승리');
  static const firstTwoPair =
      Achievement('first_two_pair', '투 페어', '투 페어로 승리');
  static const firstTrips =
      Achievement('first_trips', '트리플', '트리플로 승리');
  static const firstStraight =
      Achievement('first_straight', '스트레이트', '스트레이트로 승리');
  static const firstFlush = Achievement('first_flush', '플러시', '플러시로 승리');
  static const firstFullHouse =
      Achievement('first_full_house', '풀하우스', '풀하우스로 승리');
  static const firstQuads =
      Achievement('first_quads', '포카드', '포카드로 승리');
  static const firstStraightFlush = Achievement(
      'first_straight_flush', '스트레이트 플러시', '스트레이트 플러시로 승리');
  static const streak3 = Achievement('streak_3', '3연승', '세 핸드를 연속으로 이겼습니다');
  static const streak5 = Achievement('streak_5', '5연승', '다섯 핸드를 연속으로 이겼습니다');
  static const bigPot500 =
      Achievement('big_pot_500', '거액의 팟', '500 이상의 팟을 차지');
  static const bigPot2000 =
      Achievement('big_pot_2000', '대박', '2000 이상의 팟을 차지');
  static const tournamentWin =
      Achievement('tournament_win', '토너먼트 우승', '토너먼트에서 최후까지 살아남았습니다');

  static const List<Achievement> all = [
    firstWin,
    firstPair,
    firstTwoPair,
    firstTrips,
    firstStraight,
    firstFlush,
    firstFullHouse,
    firstQuads,
    firstStraightFlush,
    streak3,
    streak5,
    bigPot500,
    bigPot2000,
    tournamentWin,
  ];

  static Achievement? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  static Achievement? forCategory(HandCategory c) {
    return switch (c) {
      HandCategory.onePair => firstPair,
      HandCategory.twoPair => firstTwoPair,
      HandCategory.threeOfAKind => firstTrips,
      HandCategory.straight => firstStraight,
      HandCategory.flush => firstFlush,
      HandCategory.fullHouse => firstFullHouse,
      HandCategory.fourOfAKind => firstQuads,
      HandCategory.straightFlush => firstStraightFlush,
      HandCategory.highCard => null,
    };
  }
}

class GameStats {
  int handsPlayed;
  int handsWon;
  int totalWinnings;
  int biggestPot;
  int currentStreak;
  int longestStreak;
  int tournamentsWon;
  final Set<String> unlocked;

  GameStats({
    this.handsPlayed = 0,
    this.handsWon = 0,
    this.totalWinnings = 0,
    this.biggestPot = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.tournamentsWon = 0,
    Set<String>? unlocked,
  }) : unlocked = unlocked ?? <String>{};

  Map<String, dynamic> toJson() => {
        'handsPlayed': handsPlayed,
        'handsWon': handsWon,
        'totalWinnings': totalWinnings,
        'biggestPot': biggestPot,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'tournamentsWon': tournamentsWon,
        'unlocked': unlocked.toList(),
      };

  static GameStats fromJson(Map<String, dynamic> j) => GameStats(
        handsPlayed: (j['handsPlayed'] as int?) ?? 0,
        handsWon: (j['handsWon'] as int?) ?? 0,
        totalWinnings: (j['totalWinnings'] as int?) ?? 0,
        biggestPot: (j['biggestPot'] as int?) ?? 0,
        currentStreak: (j['currentStreak'] as int?) ?? 0,
        longestStreak: (j['longestStreak'] as int?) ?? 0,
        tournamentsWon: (j['tournamentsWon'] as int?) ?? 0,
        unlocked: ((j['unlocked'] as List?) ?? const [])
            .map((e) => e.toString())
            .toSet(),
      );

  static GameStats load() {
    final raw = StatsStore.load();
    if (raw == null || raw.isEmpty) return GameStats();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return fromJson(map);
    } catch (_) {
      return GameStats();
    }
  }

  void save() => StatsStore.save(jsonEncode(toJson()));

  /// Records a completed hand. Returns newly-unlocked achievements.
  List<Achievement> recordHand({
    required bool humanWon,
    required int winnings,
    required int potSize,
    HandCategory? category,
  }) {
    handsPlayed += 1;
    final fresh = <Achievement>[];

    if (humanWon) {
      handsWon += 1;
      totalWinnings += winnings;
      currentStreak += 1;
      if (currentStreak > longestStreak) longestStreak = currentStreak;
      if (potSize > biggestPot) biggestPot = potSize;

      // First-win achievement
      _unlock(Achievements.firstWin, fresh);
      final catAch = category == null
          ? null
          : Achievements.forCategory(category);
      if (catAch != null) _unlock(catAch, fresh);
      if (currentStreak >= 3) _unlock(Achievements.streak3, fresh);
      if (currentStreak >= 5) _unlock(Achievements.streak5, fresh);
      if (potSize >= 500) _unlock(Achievements.bigPot500, fresh);
      if (potSize >= 2000) _unlock(Achievements.bigPot2000, fresh);
    } else {
      currentStreak = 0;
    }

    save();
    return fresh;
  }

  List<Achievement> recordTournamentWin() {
    tournamentsWon += 1;
    final fresh = <Achievement>[];
    _unlock(Achievements.tournamentWin, fresh);
    save();
    return fresh;
  }

  void _unlock(Achievement a, List<Achievement> sink) {
    if (unlocked.add(a.id)) sink.add(a);
  }
}
