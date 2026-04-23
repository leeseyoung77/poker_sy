import 'package:flutter_test/flutter_test.dart';
import 'package:poker5/models/card.dart';
import 'package:poker5/models/hand_evaluator.dart';

PlayingCard c(String rank, Suit suit) {
  final r = switch (rank) {
    '2' => Rank.two, '3' => Rank.three, '4' => Rank.four, '5' => Rank.five,
    '6' => Rank.six, '7' => Rank.seven, '8' => Rank.eight, '9' => Rank.nine,
    'T' => Rank.ten, 'J' => Rank.jack, 'Q' => Rank.queen, 'K' => Rank.king,
    'A' => Rank.ace,
    _ => throw ArgumentError('bad rank $rank'),
  };
  return PlayingCard(r, suit);
}

void main() {
  test('straight flush detected', () {
    final h = HandEvaluator.evaluate([
      c('9', Suit.hearts), c('8', Suit.hearts), c('7', Suit.hearts),
      c('6', Suit.hearts), c('5', Suit.hearts),
      c('K', Suit.clubs), c('2', Suit.diamonds),
    ]);
    expect(h.category, HandCategory.straightFlush);
    expect(h.tiebreakers.first, 9);
  });

  test('wheel straight (A-2-3-4-5)', () {
    final h = HandEvaluator.evaluate([
      c('A', Suit.hearts), c('2', Suit.clubs), c('3', Suit.diamonds),
      c('4', Suit.spades), c('5', Suit.hearts),
      c('K', Suit.clubs), c('Q', Suit.diamonds),
    ]);
    expect(h.category, HandCategory.straight);
    expect(h.tiebreakers.first, 5);
  });

  test('four of a kind beats full house', () {
    final four = HandEvaluator.evaluate([
      c('K', Suit.hearts), c('K', Suit.clubs), c('K', Suit.diamonds),
      c('K', Suit.spades), c('3', Suit.hearts),
      c('2', Suit.clubs), c('A', Suit.diamonds),
    ]);
    final full = HandEvaluator.evaluate([
      c('A', Suit.hearts), c('A', Suit.clubs), c('A', Suit.diamonds),
      c('K', Suit.spades), c('K', Suit.hearts),
      c('2', Suit.clubs), c('3', Suit.diamonds),
    ]);
    expect(four.compareTo(full), greaterThan(0));
  });

  test('two pair tiebreaker', () {
    final a = HandEvaluator.evaluate([
      c('K', Suit.hearts), c('K', Suit.clubs),
      c('5', Suit.diamonds), c('5', Suit.spades),
      c('A', Suit.hearts), c('2', Suit.clubs), c('3', Suit.diamonds),
    ]);
    final b = HandEvaluator.evaluate([
      c('Q', Suit.hearts), c('Q', Suit.clubs),
      c('J', Suit.diamonds), c('J', Suit.spades),
      c('A', Suit.hearts), c('2', Suit.clubs), c('3', Suit.diamonds),
    ]);
    expect(a.compareTo(b), greaterThan(0));
  });

  test('flush beats straight', () {
    final flush = HandEvaluator.evaluate([
      c('A', Suit.hearts), c('J', Suit.hearts), c('9', Suit.hearts),
      c('6', Suit.hearts), c('3', Suit.hearts),
      c('K', Suit.clubs), c('Q', Suit.diamonds),
    ]);
    final straight = HandEvaluator.evaluate([
      c('9', Suit.hearts), c('8', Suit.clubs), c('7', Suit.diamonds),
      c('6', Suit.spades), c('5', Suit.hearts),
      c('K', Suit.clubs), c('2', Suit.diamonds),
    ]);
    expect(flush.compareTo(straight), greaterThan(0));
  });
}
