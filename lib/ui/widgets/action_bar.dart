import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../game/game_engine.dart';
import '../../game/player.dart';
import '../theme.dart';

const double kActionBarWidth = 82;

class ActionBar extends StatelessWidget {
  final GameEngine engine;
  final VoidCallback onSettings;
  final VoidCallback onHistory;
  final VoidCallback onStats;
  final int achievementsCount;
  final int achievementsTotal;
  const ActionBar({
    super.key,
    required this.engine,
    required this.onSettings,
    required this.onHistory,
    required this.onStats,
    required this.achievementsCount,
    required this.achievementsTotal,
  });

  List<Widget> _toolsColumn() => [
        _MiniIcon(icon: Icons.settings, onTap: onSettings),
        const SizedBox(height: 4),
        _MiniIcon(icon: Icons.history, onTap: onHistory),
        const SizedBox(height: 4),
        _MiniIcon(
          icon: Icons.emoji_events,
          iconColor: AppColors.highlight,
          onTap: onStats,
          label: '$achievementsCount/$achievementsTotal',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (engine.street == Street.handComplete) {
      content = _NewHandContent(engine: engine, tools: _toolsColumn());
    } else if (engine.declarationOpen) {
      content = _DeclarationContent(engine: engine, tools: _toolsColumn());
    } else if (!engine.awaitingHumanAction) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _toolsColumn(),
      );
    } else {
      content = _ActionContent(engine: engine, tools: _toolsColumn());
    }
    return Container(
      width: kActionBarWidth,
      decoration: const BoxDecoration(
        color: AppColors.bgElevated,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
      child: content,
    );
  }
}

class _ActionContent extends StatelessWidget {
  final GameEngine engine;
  final List<Widget> tools;
  const _ActionContent({required this.engine, required this.tools});

  @override
  Widget build(BuildContext context) {
    final human = engine.players.firstWhere(
      (p) => p.isHuman,
      orElse: () => engine.players.first,
    );
    final toCall = engine.toCallFor(human);
    final canCheck = toCall == 0;
    final minRaise = engine.minRaiseTotal(human);
    final maxRaise = engine.maxRaiseTotal(human);
    final canRaise = maxRaise > engine.currentBet && human.stack > 0;
    final currentBet = engine.currentBet;
    final pot = engine.pot;

    int clampRaise(int t) => t.clamp(minRaise, maxRaise);
    int pping() => clampRaise(minRaise);
    int ddadang() => clampRaise(currentBet * 2);
    int quarter() => clampRaise(human.currentBet + (pot ~/ 4));
    int half() => clampRaise(human.currentBet + (pot ~/ 2));

    final canFold = human.status == PlayerStatus.active &&
        engine.street != Street.thirdStreet;

    final buttons = <Widget>[];
    buttons.add(_BetButton(
      label: '다이',
      color: AppColors.danger,
      onTap: canFold
          ? () => engine.submitAction(const PlayerAction.fold())
          : null,
    ));
    buttons.add(_BetButton(
      label: canCheck ? '체크' : '콜 $toCall',
      color: AppColors.info,
      onTap: () => engine.submitAction(
        canCheck ? const PlayerAction.check() : const PlayerAction.call(),
      ),
    ));

    if (canRaise) {
      buttons.add(_BetButton(
        label: '삥 ${pping()}',
        color: AppColors.accentMuted,
        onTap: () => engine.submitAction(PlayerAction.raise(pping())),
      ));
      if (currentBet > 0 && ddadang() > currentBet) {
        buttons.add(_BetButton(
          label: '따당 ${ddadang()}',
          color: AppColors.accent,
          onTap: () => engine.submitAction(PlayerAction.raise(ddadang())),
        ));
      }
      if (quarter() > math.max(currentBet, minRaise - 1)) {
        buttons.add(_BetButton(
          label: '쿼터 ${quarter()}',
          color: AppColors.accent,
          onTap: () => engine.submitAction(PlayerAction.raise(quarter())),
        ));
      }
      if (half() > quarter()) {
        buttons.add(_BetButton(
          label: '하프 ${half()}',
          color: AppColors.success,
          onTap: () => engine.submitAction(PlayerAction.raise(half())),
        ));
      }
      final allInAllowed = engine.street != Street.thirdStreet &&
          engine.street != Street.fourthStreet;
      if (allInAllowed && maxRaise > half()) {
        buttons.add(_BetButton(
          label: '올인 $maxRaise',
          color: AppColors.highlight,
          onTap: () => engine.submitAction(PlayerAction.raise(maxRaise)),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...tools,
        const Divider(color: AppColors.border, height: 12),
        for (var i = 0; i < buttons.length; i++) ...[
          if (i > 0) const SizedBox(height: 4),
          buttons[i],
        ],
      ],
    );
  }
}

class _DeclarationContent extends StatefulWidget {
  final GameEngine engine;
  final List<Widget> tools;
  const _DeclarationContent({required this.engine, required this.tools});

  @override
  State<_DeclarationContent> createState() => _DeclarationContentState();
}

class _DeclarationContentState extends State<_DeclarationContent> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted && widget.engine.declarationOpen) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final secondsLeft = widget.engine.declarationSecondsRemaining.ceil();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...widget.tools,
        const Divider(color: AppColors.border, height: 12),
        const Text(
          '선 선언',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.highlight,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
        Text(
          '$secondsLeft 초',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 4),
        ElevatedButton(
          onPressed: widget.engine.declareHuman,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.highlight,
            foregroundColor: AppColors.bg,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            minimumSize: const Size(0, 32),
          ),
          child: const Text(
            '선언',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

class _NewHandContent extends StatelessWidget {
  final GameEngine engine;
  final List<Widget> tools;
  const _NewHandContent({required this.engine, required this.tools});

  @override
  Widget build(BuildContext context) {
    final human = engine.players.firstWhere(
      (p) => p.isHuman,
      orElse: () => engine.players.first,
    );
    final humanOut =
        human.stack <= 0 || human.status == PlayerStatus.out;
    final isInitial = engine.isInitialState;
    final tournamentOver = engine.tournamentOver;
    final winner = engine.tournamentWinner;

    final String label;
    final IconData icon;
    final Color bgColor;
    final VoidCallback onPressed;
    String? caption;

    if (tournamentOver) {
      final humanWon = winner?.isHuman ?? false;
      caption = humanWon ? '🏆 우승!' : '토너먼트 종료';
      label = '재시작';
      icon = Icons.refresh;
      bgColor = humanWon ? AppColors.highlight : AppColors.accent;
      onPressed = () {
        engine.resetGame();
        engine.startHand();
      };
    } else if (humanOut) {
      caption = '탈락';
      label = '다시 시작';
      icon = Icons.refresh;
      bgColor = AppColors.danger;
      onPressed = () {
        engine.resetGame();
        engine.startHand();
      };
    } else if (isInitial) {
      label = '게임 시작';
      icon = Icons.play_arrow;
      bgColor = AppColors.accent;
      onPressed = engine.startHand;
    } else {
      label = '다음 핸드';
      icon = Icons.play_arrow;
      bgColor = AppColors.accent;
      onPressed = engine.startHand;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...tools,
        const Divider(color: AppColors.border, height: 12),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              caption,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 13),
          label: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: bgColor,
            foregroundColor: AppColors.bg,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            minimumSize: const Size(0, 32),
          ),
        ),
      ],
    );
  }
}

class _MiniIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;
  final String? label;
  const _MiniIcon({
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.bgPanel,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 14, color: iconColor ?? AppColors.textSecondary),
              if (label != null) ...[
                const SizedBox(width: 3),
                Text(
                  label!,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BetButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _BetButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledForegroundColor: AppColors.textMuted,
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
            color: enabled ? color.withAlpha(70) : AppColors.border,
            width: 0.8,
          ),
        ),
        minimumSize: const Size(0, 30),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          label,
          maxLines: 1,
          style: TextStyle(
            color: enabled ? color : AppColors.textMuted,
            fontWeight: FontWeight.w900,
            fontSize: 10,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
