import 'card.dart';

enum HandCategory {
  highCard,
  onePair,
  twoPair,
  threeOfAKind,
  straight,
  flush,
  fullHouse,
  fourOfAKind,
  straightFlush,
}

extension HandCategoryX on HandCategory {
  String get label => switch (this) {
        HandCategory.highCard => '하이카드',
        HandCategory.onePair => '원 페어',
        HandCategory.twoPair => '투 페어',
        HandCategory.threeOfAKind => '트리플',
        HandCategory.straight => '스트레이트',
        HandCategory.flush => '플러시',
        HandCategory.fullHouse => '풀하우스',
        HandCategory.fourOfAKind => '포카드',
        HandCategory.straightFlush => '스트레이트 플러시',
      };
}

class HandRank implements Comparable<HandRank> {
  final HandCategory category;
  final List<int> tiebreakers;
  final List<PlayingCard> bestFive;

  const HandRank({
    required this.category,
    required this.tiebreakers,
    required this.bestFive,
  });

  @override
  int compareTo(HandRank other) {
    final c = category.index.compareTo(other.category.index);
    if (c != 0) return c;
    for (var i = 0; i < tiebreakers.length && i < other.tiebreakers.length; i++) {
      final d = tiebreakers[i].compareTo(other.tiebreakers[i]);
      if (d != 0) return d;
    }
    return 0;
  }

  String get label => category.label;

  /// Richer Korean label including the key rank(s), e.g. "에이스 투 페어",
  /// "킹 풀하우스 (텐 풀)", "로얄 스트레이트 플러시".
  String get detailedLabel {
    if (tiebreakers.isEmpty) return category.label;
    final top = _rankName(tiebreakers.first);
    switch (category) {
      case HandCategory.highCard:
        return '$top 하이';
      case HandCategory.onePair:
        return '$top 원 페어';
      case HandCategory.twoPair:
        final second =
            tiebreakers.length >= 2 ? _rankName(tiebreakers[1]) : null;
        return second != null
            ? '$top · $second 투 페어'
            : '$top 투 페어';
      case HandCategory.threeOfAKind:
        return '$top 트리플';
      case HandCategory.straight:
        return '$top 스트레이트';
      case HandCategory.flush:
        return '$top 플러시';
      case HandCategory.fullHouse:
        final over =
            tiebreakers.length >= 2 ? _rankName(tiebreakers[1]) : null;
        return over != null
            ? '$top 풀하우스 ($over 풀)'
            : '$top 풀하우스';
      case HandCategory.fourOfAKind:
        return '$top 포카드';
      case HandCategory.straightFlush:
        if (tiebreakers.first == 14) return '로얄 스트레이트 플러시';
        return '$top 스트레이트 플러시';
    }
  }

  static String _rankName(int v) => switch (v) {
        14 => '에이스',
        13 => '킹',
        12 => '퀸',
        11 => '잭',
        10 => '텐',
        9 => '나인',
        8 => '에이트',
        7 => '세븐',
        6 => '식스',
        5 => '파이브',
        4 => '포',
        3 => '쓰리',
        2 => '투',
        _ => '$v',
      };
}

class HandEvaluator {
  static HandRank evaluate(List<PlayingCard> cards) {
    assert(cards.length >= 5 && cards.length <= 7);

    final sorted = [...cards]..sort((a, b) => b.rank.value.compareTo(a.rank.value));

    final bySuit = <Suit, List<PlayingCard>>{};
    for (final c in sorted) {
      bySuit.putIfAbsent(c.suit, () => []).add(c);
    }

    // Straight flush
    for (final entry in bySuit.entries) {
      if (entry.value.length >= 5) {
        final sf = _findStraight(entry.value);
        if (sf != null) {
          return HandRank(
            category: HandCategory.straightFlush,
            tiebreakers: [sf.first.rank.value],
            bestFive: sf,
          );
        }
      }
    }

    // Rank counts
    final counts = <int, List<PlayingCard>>{};
    for (final c in sorted) {
      counts.putIfAbsent(c.rank.value, () => []).add(c);
    }
    final byCount = counts.entries.toList()
      ..sort((a, b) {
        final c = b.value.length.compareTo(a.value.length);
        if (c != 0) return c;
        return b.key.compareTo(a.key);
      });

    // Four of a kind
    if (byCount.first.value.length == 4) {
      final four = byCount.first.value;
      final kicker = sorted.firstWhere((c) => c.rank.value != byCount.first.key);
      return HandRank(
        category: HandCategory.fourOfAKind,
        tiebreakers: [byCount.first.key, kicker.rank.value],
        bestFive: [...four, kicker],
      );
    }

    // Full house
    if (byCount.first.value.length == 3 &&
        byCount.length >= 2 &&
        byCount[1].value.length >= 2) {
      final three = byCount.first.value;
      final pair = byCount[1].value.take(2).toList();
      return HandRank(
        category: HandCategory.fullHouse,
        tiebreakers: [byCount.first.key, byCount[1].key],
        bestFive: [...three, ...pair],
      );
    }

    // Flush
    for (final entry in bySuit.entries) {
      if (entry.value.length >= 5) {
        final five = entry.value.take(5).toList();
        return HandRank(
          category: HandCategory.flush,
          tiebreakers: five.map((c) => c.rank.value).toList(),
          bestFive: five,
        );
      }
    }

    // Straight
    final straight = _findStraight(sorted);
    if (straight != null) {
      return HandRank(
        category: HandCategory.straight,
        tiebreakers: [straight.first.rank.value],
        bestFive: straight,
      );
    }

    // Three of a kind
    if (byCount.first.value.length == 3) {
      final three = byCount.first.value;
      final kickers = sorted
          .where((c) => c.rank.value != byCount.first.key)
          .take(2)
          .toList();
      return HandRank(
        category: HandCategory.threeOfAKind,
        tiebreakers: [
          byCount.first.key,
          ...kickers.map((c) => c.rank.value),
        ],
        bestFive: [...three, ...kickers],
      );
    }

    // Two pair
    if (byCount.first.value.length == 2 &&
        byCount.length >= 2 &&
        byCount[1].value.length == 2) {
      final highPair = byCount.first.value;
      final lowPair = byCount[1].value;
      final kicker = sorted
          .firstWhere((c) =>
              c.rank.value != byCount.first.key &&
              c.rank.value != byCount[1].key);
      return HandRank(
        category: HandCategory.twoPair,
        tiebreakers: [byCount.first.key, byCount[1].key, kicker.rank.value],
        bestFive: [...highPair, ...lowPair, kicker],
      );
    }

    // One pair
    if (byCount.first.value.length == 2) {
      final pair = byCount.first.value;
      final kickers = sorted
          .where((c) => c.rank.value != byCount.first.key)
          .take(3)
          .toList();
      return HandRank(
        category: HandCategory.onePair,
        tiebreakers: [
          byCount.first.key,
          ...kickers.map((c) => c.rank.value),
        ],
        bestFive: [...pair, ...kickers],
      );
    }

    // High card
    final five = sorted.take(5).toList();
    return HandRank(
      category: HandCategory.highCard,
      tiebreakers: five.map((c) => c.rank.value).toList(),
      bestFive: five,
    );
  }

  /// Returns 5 cards forming the highest straight, or null.
  /// Input is sorted by rank descending. Handles the wheel (A-2-3-4-5).
  static List<PlayingCard>? _findStraight(List<PlayingCard> sortedDesc) {
    final seen = <int, PlayingCard>{};
    for (final c in sortedDesc) {
      seen.putIfAbsent(c.rank.value, () => c);
    }
    final uniqueRanks = seen.keys.toList()..sort((a, b) => b.compareTo(a));
    if (uniqueRanks.length < 5) {
      // Still may be a wheel if we have A,2,3,4,5.
    }

    for (var i = 0; i + 4 < uniqueRanks.length; i++) {
      if (uniqueRanks[i] - uniqueRanks[i + 4] == 4) {
        return [
          for (var k = 0; k < 5; k++) seen[uniqueRanks[i + k]]!,
        ];
      }
    }
    // Wheel: A-5-4-3-2
    if (uniqueRanks.contains(14) &&
        uniqueRanks.contains(5) &&
        uniqueRanks.contains(4) &&
        uniqueRanks.contains(3) &&
        uniqueRanks.contains(2)) {
      return [seen[5]!, seen[4]!, seen[3]!, seen[2]!, seen[14]!];
    }
    return null;
  }
}
