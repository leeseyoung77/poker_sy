import 'dart:math';
import 'card.dart';

class Deck {
  final List<PlayingCard> _cards = [];
  final Random _rng;

  Deck({int? seed}) : _rng = Random(seed) {
    reset();
  }

  void reset() {
    _cards.clear();
    for (final s in Suit.values) {
      for (final r in Rank.all) {
        _cards.add(PlayingCard(r, s));
      }
    }
  }

  void shuffle() {
    _cards.shuffle(_rng);
  }

  PlayingCard draw() {
    if (_cards.isEmpty) {
      throw StateError('Deck is empty');
    }
    return _cards.removeLast();
  }

  List<PlayingCard> drawMany(int n) =>
      List.generate(n, (_) => draw(), growable: false);

  int get remaining => _cards.length;
}
