/// AI playstyle archetypes. Each carries numeric knobs that tune the base
/// strategy in [PokerAI] so every opponent plays noticeably differently.
enum AiPersonality { aggressive, calculated, timid, unpredictable }

class AiPersonalityProfile {
  /// Label shown next to the player's name.
  final String badge;

  /// Cartoon emoji used as the avatar for this personality.
  final String emoji;

  /// Accent colour of the avatar ring.
  final int accentArgb;

  /// Adds to hand strength before comparisons. Higher = bets more often,
  /// bluffs more. Lower = folds more.
  final double confidenceBias;

  /// Fold threshold shift. Higher = folds more readily. Negative = sticks around.
  final double foldBias;

  /// Raise threshold. Lower = raises more freely.
  final double raiseThreshold;

  /// Multiplies the raise sizing (fraction of pot).
  final double betSizeMultiplier;

  /// Random noise added to the strength estimate. Big value = chaotic.
  final double jitter;

  /// Probability to declare 선 on 3rd street when they otherwise wouldn't.
  /// Aggressive/unpredictable players "claim" more often.
  final double declareBoost;

  /// Phrases bucketed by action kind.
  final Map<String, List<String>> phrases;

  const AiPersonalityProfile({
    required this.badge,
    required this.emoji,
    required this.accentArgb,
    required this.confidenceBias,
    required this.foldBias,
    required this.raiseThreshold,
    required this.betSizeMultiplier,
    required this.jitter,
    required this.declareBoost,
    required this.phrases,
  });

  static const aggressive = AiPersonalityProfile(
    badge: '공격형',
    emoji: '😈',
    accentArgb: 0xFFe25858,
    confidenceBias: 0.10,
    foldBias: -0.08,
    raiseThreshold: 0.50,
    betSizeMultiplier: 1.35,
    jitter: 0.08,
    declareBoost: 0.15,
    phrases: {
      'raise': ['간다!', '올려!', '가자!', '이거다!'],
      'call': ['좋다.', '받지.', '콜.'],
      'check': ['흠…', '기다려볼까.'],
      'fold': ['쳇, 죽자.', '다음을 보자.'],
      'declare': ['내가 선이다!', '덤벼!'],
    },
  );

  static const calculated = AiPersonalityProfile(
    badge: '계산가',
    emoji: '🧐',
    accentArgb: 0xFF5e8ab8,
    confidenceBias: 0.0,
    foldBias: 0.0,
    raiseThreshold: 0.70,
    betSizeMultiplier: 0.95,
    jitter: 0.03,
    declareBoost: 0.0,
    phrases: {
      'raise': ['+EV입니다.', '수가 맞네요.', '레이즈.'],
      'call': ['팟 오즈 콜.', '합리적.', '콜합니다.'],
      'check': ['관망.', '정보 수집.'],
      'fold': ['손해 회피.', '폴드.'],
      'declare': ['제가 최강입니다.'],
    },
  );

  static const timid = AiPersonalityProfile(
    badge: '소심',
    emoji: '😰',
    accentArgb: 0xFF9aa0a6,
    confidenceBias: -0.05,
    foldBias: 0.12,
    raiseThreshold: 0.82,
    betSizeMultiplier: 0.65,
    jitter: 0.04,
    declareBoost: -0.15,
    phrases: {
      'raise': ['자… 작게만.', '올립니다…'],
      'call': ['콜, 콜…', '받을게요.'],
      'check': ['체크…', '조용히 갑니다.'],
      'fold': ['죽을게요…', '안 되겠어요.'],
      'declare': ['저… 선 해도 될까요?'],
    },
  );

  static const unpredictable = AiPersonalityProfile(
    badge: '예측불가',
    emoji: '🤪',
    accentArgb: 0xFFffb300,
    confidenceBias: 0.05,
    foldBias: -0.04,
    raiseThreshold: 0.55,
    betSizeMultiplier: 1.10,
    jitter: 0.22,
    declareBoost: 0.20,
    phrases: {
      'raise': ['얍!', '훅~', '랜덤!', '가보자고!'],
      'call': ['콜콜콜~', '오케이!'],
      'check': ['음~', '체크!'],
      'fold': ['빠이~', '재밌었다!'],
      'declare': ['내가 간드아~'],
    },
  );

  static AiPersonalityProfile of(AiPersonality p) => switch (p) {
        AiPersonality.aggressive => aggressive,
        AiPersonality.calculated => calculated,
        AiPersonality.timid => timid,
        AiPersonality.unpredictable => unpredictable,
      };
}
