enum Suit { spades, hearts, diamonds, clubs }

extension SuitX on Suit {
  String get symbol => switch (this) {
        Suit.spades => '♠',
        Suit.hearts => '♥',
        Suit.diamonds => '♦',
        Suit.clubs => '♣',
      };

  bool get isRed => this == Suit.hearts || this == Suit.diamonds;
}

class Rank {
  final int value;
  const Rank._(this.value);

  static const two = Rank._(2);
  static const three = Rank._(3);
  static const four = Rank._(4);
  static const five = Rank._(5);
  static const six = Rank._(6);
  static const seven = Rank._(7);
  static const eight = Rank._(8);
  static const nine = Rank._(9);
  static const ten = Rank._(10);
  static const jack = Rank._(11);
  static const queen = Rank._(12);
  static const king = Rank._(13);
  static const ace = Rank._(14);

  static const all = [
    two, three, four, five, six, seven, eight, nine, ten,
    jack, queen, king, ace,
  ];

  String get label => switch (value) {
        11 => 'J',
        12 => 'Q',
        13 => 'K',
        14 => 'A',
        _ => '$value',
      };

  @override
  bool operator ==(Object other) => other is Rank && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class PlayingCard {
  final Rank rank;
  final Suit suit;
  const PlayingCard(this.rank, this.suit);

  String get label => '${rank.label}${suit.symbol}';

  @override
  String toString() => label;

  @override
  bool operator ==(Object other) =>
      other is PlayingCard && other.rank == rank && other.suit == suit;

  @override
  int get hashCode => Object.hash(rank, suit);
}
