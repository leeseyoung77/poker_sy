import '../models/card.dart';
import 'ai_personality.dart';

enum PlayerStatus { active, folded, allIn, out }

class Player {
  final int seat;
  final String name;
  final bool isHuman;
  final int initialStack;
  final AiPersonality aiPersonality;

  int stack;
  int currentBet = 0;
  int totalContributed = 0;
  PlayerStatus status = PlayerStatus.active;
  List<PlayingCard> downCards = const [];
  List<PlayingCard> upCards = const [];
  bool hasActedThisRound = false;

  final String? avatarAsset;

  Player({
    required this.seat,
    required this.name,
    required this.isHuman,
    int startingStack = 1000,
    this.aiPersonality = AiPersonality.calculated,
    this.avatarAsset,
  })  : initialStack = startingStack,
        stack = startingStack;

  /// Reset to the starting state for a brand-new game.
  void fullReset() {
    stack = initialStack;
    currentBet = 0;
    totalContributed = 0;
    downCards = const [];
    upCards = const [];
    hasActedThisRound = false;
    status = PlayerStatus.active;
  }

  List<PlayingCard> get allCards => [...downCards, ...upCards];

  bool get canAct => status == PlayerStatus.active && stack > 0;

  bool get inHand =>
      status == PlayerStatus.active || status == PlayerStatus.allIn;

  void resetForHand() {
    currentBet = 0;
    totalContributed = 0;
    downCards = const [];
    upCards = const [];
    hasActedThisRound = false;
    if (stack <= 0) {
      status = PlayerStatus.out;
    } else {
      status = PlayerStatus.active;
    }
  }

  void resetForBettingRound() {
    currentBet = 0;
    hasActedThisRound = false;
  }
}
