import 'package:flutter/material.dart';

import '../../game/ai_personality.dart';
import '../../game/player.dart';
import '../../models/card.dart';
import '../theme.dart';
import 'card_widget.dart';

class PlayerSeat extends StatelessWidget {
  final Player player;
  final bool isActor;
  final bool revealDownCards;
  final List<PlayingCard> highlightCards;
  final String? badge;

  const PlayerSeat({
    super.key,
    required this.player,
    this.isActor = false,
    this.revealDownCards = false,
    this.highlightCards = const [],
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final cardWidth = player.isHuman ? 38.0 : 32.0;
    final folded = player.status == PlayerStatus.folded;
    final out = player.status == PlayerStatus.out;
    final showDown = player.isHuman || revealDownCards;

    final ordered = <_CardEntry>[
      for (final c in player.downCards) _CardEntry(c, !showDown),
      for (final c in player.upCards) _CardEntry(c, false),
    ];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: folded || out ? 0.45 : 1.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FannedCards(
            cards: ordered,
            cardWidth: cardWidth,
            highlighted: highlightCards,
          ),
          const SizedBox(height: 4),
          _NamePlate(
            player: player,
            isActor: isActor,
            folded: folded,
            out: out,
          ),
          if (player.currentBet > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  '${player.currentBet}',
                  style: const TextStyle(
                    color: AppColors.bg,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NamePlate extends StatelessWidget {
  final Player player;
  final bool isActor;
  final bool folded;
  final bool out;
  const _NamePlate({
    required this.player,
    required this.isActor,
    required this.folded,
    required this.out,
  });

  @override
  Widget build(BuildContext context) {
    final profile = player.isHuman
        ? null
        : AiPersonalityProfile.of(player.aiPersonality);
    final showAvatar = profile != null;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: showAvatar ? 6 : AppSpacing.md,
        vertical: showAvatar ? 4 : 7,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isActor ? AppColors.highlight : AppColors.border,
          width: isActor ? 2 : 1,
        ),
        boxShadow: isActor
            ? [
                BoxShadow(
                  color: AppColors.highlight.withAlpha(60),
                  blurRadius: 10,
                ),
              ]
            : const [],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showAvatar) ...[
            _InlineAvatar(
              assetPath: player.avatarAsset,
              emoji: profile.emoji,
              accent: Color(profile.accentArgb),
              isActor: isActor,
            ),
            const SizedBox(width: 8),
          ],
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.name,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.2,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${player.stack}',
                style: const TextStyle(
                  color: AppColors.highlight,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              if (folded)
                const Text('FOLD',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ))
              else if (player.status == PlayerStatus.allIn)
                const Text('ALL-IN',
                    style: TextStyle(
                      color: AppColors.highlight,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ))
              else if (out)
                const Text('OUT',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    )),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineAvatar extends StatelessWidget {
  final String? assetPath;
  final String emoji;
  final Color accent;
  final bool isActor;
  const _InlineAvatar({
    required this.assetPath,
    required this.emoji,
    required this.accent,
    required this.isActor,
  });

  @override
  Widget build(BuildContext context) {
    const size = 54.0;
    final borderColor = isActor ? AppColors.highlight : accent;
    Widget inner;
    if (assetPath == null) {
      inner = Container(
        alignment: Alignment.center,
        color: AppColors.bgSunken,
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 28, height: 1.0),
        ),
      );
    } else {
      inner = Image.asset(
        assetPath!,
        fit: BoxFit.cover,
        errorBuilder: (_, e, s) => Container(
          alignment: Alignment.center,
          color: AppColors.bgSunken,
          child: Text(emoji, style: const TextStyle(fontSize: 28)),
        ),
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.bgSunken,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: isActor ? 2.5 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: borderColor.withAlpha(110),
            blurRadius: isActor ? 12 : 6,
          ),
        ],
      ),
      child: ClipOval(child: inner),
    );
  }
}

class _CardEntry {
  final PlayingCard card;
  final bool faceDown;
  const _CardEntry(this.card, this.faceDown);
}

class _FannedCards extends StatelessWidget {
  final List<_CardEntry> cards;
  final double cardWidth;
  final List<PlayingCard> highlighted;

  const _FannedCards({
    required this.cards,
    required this.cardWidth,
    required this.highlighted,
  });

  @override
  Widget build(BuildContext context) {
    final height = cardWidth * 1.45;
    if (cards.isEmpty) {
      return SizedBox(height: height);
    }
    final step = cardWidth * 0.55;
    final totalWidth = cardWidth + (cards.length - 1) * step;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: totalWidth,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < cards.length; i++)
              Positioned(
                left: i * step,
                top: 0,
                child: CardWidget(
                  card: cards[i].card,
                  faceDown: cards[i].faceDown,
                  width: cardWidth,
                  highlighted: highlighted.contains(cards[i].card),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
