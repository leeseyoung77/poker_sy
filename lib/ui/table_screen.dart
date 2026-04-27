import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../game/ai_personality.dart';
import '../game/game_engine.dart';
import '../game/game_stats.dart';
import '../game/player.dart';
import '../models/card.dart';
import '../update/updater.dart';
import 'theme.dart';
import 'widgets/achievement_toast.dart';
import 'widgets/action_bar.dart';
import 'widgets/history_dialog.dart';
import 'widgets/player_seat.dart';
import 'widgets/settings_dialog.dart';
import 'widgets/stats_dialog.dart';

class TableScreen extends StatefulWidget {
  const TableScreen({super.key});

  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> {
  late final GameEngine engine;
  late final GameStats stats;
  Achievement? _toastAchievement;
  late final AchievementToastController _toaster;
  Timer? _tick;
  final List<_FlyingChipEvent> _flys = [];
  int _flyId = 0;
  bool _celebrating = false;
  Timer? _celebrateTimer;
  final Map<int, String> _bubbles = {};
  final Map<int, Timer> _bubbleTimers = {};
  final math.Random _bubbleRng = math.Random();
  final List<_FlyingCardEvent> _dealingCards = [];
  int _dealId = 0;

  @override
  void initState() {
    super.initState();
    Sfx.init();
    stats = GameStats.load();
    _toaster = AchievementToastController(
      (a) => setState(() => _toastAchievement = a),
    );
    engine = GameEngine(
      players: [
        Player(seat: 0, name: '당신', isHuman: true),
        Player(
          seat: 1,
          name: '용이',
          isHuman: false,
          aiPersonality: AiPersonality.aggressive,
          avatarAsset: 'assets/images/avatar_minsu.png',
        ),
        Player(
          seat: 2,
          name: '세롱',
          isHuman: false,
          aiPersonality: AiPersonality.calculated,
          avatarAsset: 'assets/images/avatar_jiyoung.png',
        ),
        Player(
          seat: 3,
          name: '창호',
          isHuman: false,
          aiPersonality: AiPersonality.timid,
          avatarAsset: 'assets/images/avatar_hyunwoo.png',
        ),
        Player(
          seat: 4,
          name: '수진',
          isHuman: false,
          aiPersonality: AiPersonality.unpredictable,
        ),
      ],
      onDeal: _onDeal,
      onHumanTurn: Sfx.playTurn,
      onChipsToPot: _queueChipFly,
      onHumanWin: _onHumanWin,
      onTournamentEnd: _onTournamentEnd,
      onPlayerAction: _onPlayerAction,
    );
    engine.addListener(_onEngineChange);
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      if (engine.showTurnCountdown) setState(() {});
    });
    // No auto-start — wait for the user to press the start button.
    // After the first frame, quietly check GitHub for a newer release.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.check(context);
    });
  }

  static const _flyPalette = <Color>[
    Color(0xFFe25858), // red
    Color(0xFF00bfa6), // teal
    Color(0xFFffb300), // amber
    Color(0xFF5e8ab8), // blue
    Color(0xFF212121), // black
    Color(0xFF7b1fa2), // purple
  ];

  void _onDeal() {
    Sfx.playDeal();
    if (!mounted) return;
    for (var i = 0; i < engine.players.length; i++) {
      final p = engine.players[i];
      if (p.status != PlayerStatus.active && p.status != PlayerStatus.allIn) {
        continue;
      }
      final delay = i * 60;
      Future.delayed(Duration(milliseconds: delay), () {
        if (!mounted) return;
        final id = _dealId++;
        setState(() {
          _dealingCards.add(_FlyingCardEvent(id: id, seat: p.seat));
        });
      });
    }
  }

  void _removeDealingCard(int id) {
    _dealingCards.removeWhere((e) => e.id == id);
    if (mounted) setState(() {});
  }

  void _onHumanWin() {
    Sfx.playFanfare();
    if (!mounted) return;
    setState(() => _celebrating = true);
    _celebrateTimer?.cancel();
    _celebrateTimer = Timer(const Duration(milliseconds: 4200), () {
      if (mounted) setState(() => _celebrating = false);
    });
  }

  void _onTournamentEnd(Player winner) {
    if (!winner.isHuman) return;
    final unlocked = stats.recordTournamentWin();
    if (unlocked.isNotEmpty) _toaster.enqueue(unlocked);
  }

  void _onPlayerAction(Player player, String tag) {
    if (player.isHuman) return;
    final profile = AiPersonalityProfile.of(player.aiPersonality);
    final pool = profile.phrases[tag];
    if (pool == null || pool.isEmpty) return;
    final phrase = pool[_bubbleRng.nextInt(pool.length)];
    if (!mounted) return;
    setState(() => _bubbles[player.seat] = phrase);
    _bubbleTimers[player.seat]?.cancel();
    _bubbleTimers[player.seat] = Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      setState(() => _bubbles.remove(player.seat));
    });
  }

  Street? _lastRecordedStreet;
  void _onEngineChange() {
    // Record stats once per hand when it transitions to handComplete.
    if (engine.street == Street.handComplete &&
        _lastRecordedStreet != Street.handComplete &&
        engine.lastShowdown.isNotEmpty) {
      _recordHandStats();
      // Fly chips from the center pile back to every winner.
      for (final r in engine.lastShowdown) {
        if (r.winnings > 0) _spawnWinnerChips(r.player, r.winnings);
      }
    }
    _lastRecordedStreet = engine.street;
  }

  void _recordHandStats() {
    final human = engine.players.firstWhere(
      (p) => p.isHuman,
      orElse: () => engine.players.first,
    );
    ShowdownResult? humanResult;
    for (final r in engine.lastShowdown) {
      if (r.player == human) {
        humanResult = r;
        break;
      }
    }
    final humanWon = humanResult != null && humanResult.winnings > 0;
    final winnings = humanResult?.winnings ?? 0;
    final potSize = engine.lastShowdown
        .fold<int>(0, (sum, r) => sum + r.winnings);
    final category = humanResult?.rank.category;

    final fresh = stats.recordHand(
      humanWon: humanWon,
      winnings: winnings,
      potSize: potSize,
      category: category,
    );
    if (fresh.isNotEmpty) _toaster.enqueue(fresh);
  }

  void _queueChipFly(Player p, int amount) {
    if (!mounted) return;
    // +1 flying chip per 50 chips wagered, capped so a huge bet doesn't spam.
    final count = (1 + amount ~/ 50).clamp(1, 14);
    _spawnChip(p.seat);
    for (var i = 1; i < count; i++) {
      Future.delayed(Duration(milliseconds: i * 45), () {
        if (mounted) _spawnChip(p.seat);
      });
    }
  }

  void _spawnChip(int seat, {bool fromCenter = false}) {
    final id = _flyId++;
    _flys.add(_FlyingChipEvent(
      id: id,
      seat: seat,
      color: _flyPalette[id % _flyPalette.length],
      fromCenter: fromCenter,
    ));
    setState(() {});
  }

  void _spawnWinnerChips(Player winner, int winnings) {
    if (winnings <= 0) return;
    final count = (1 + winnings ~/ 50).clamp(3, 16);
    _spawnChip(winner.seat, fromCenter: true);
    for (var i = 1; i < count; i++) {
      Future.delayed(Duration(milliseconds: i * 45), () {
        if (mounted) _spawnChip(winner.seat, fromCenter: true);
      });
    }
  }

  void _removeFly(int id) {
    _flys.removeWhere((e) => e.id == id);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tick?.cancel();
    _celebrateTimer?.cancel();
    _toaster.dispose();
    for (final t in _bubbleTimers.values) {
      t.cancel();
    }
    engine.removeListener(_onEngineChange);
    engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          SafeArea(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => Sfx.resume(),
              child: AnimatedBuilder(
                animation: engine,
                builder: (context, _) {
              return Row(
                children: [
                  ActionBar(
                    engine: engine,
                    onSettings: () => SettingsDialog.show(context),
                    onHistory: () => HistoryDialog.show(context, engine),
                    onStats: () => StatsDialog.show(context, stats),
                    achievementsCount: stats.unlocked.length,
                    achievementsTotal: Achievements.all.length,
                  ),
                  Expanded(
                    child: _TableArea(
                      engine: engine,
                      flys: _flys,
                      onFlyDone: _removeFly,
                      bubbles: _bubbles,
                      dealCards: _dealingCards,
                      onDealCardDone: _removeDealingCard,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
          if (_celebrating)
            const Positioned.fill(
              child: IgnorePointer(child: _WinCelebration()),
            ),
          if (_toastAchievement != null)
            Positioned(
              top: 20,
              right: 20,
              child: IgnorePointer(
                child: AchievementToast(achievement: _toastAchievement!),
              ),
            ),
        ],
      ),
    );
  }
}

class _FlyingChipEvent {
  final int id;
  final int seat;
  final Color color;
  final bool fromCenter;
  const _FlyingChipEvent({
    required this.id,
    required this.seat,
    required this.color,
    this.fromCenter = false,
  });
}

class _FlyingCardEvent {
  final int id;
  final int seat;
  const _FlyingCardEvent({required this.id, required this.seat});
}

class _TableArea extends StatelessWidget {
  final GameEngine engine;
  final List<_FlyingChipEvent> flys;
  final void Function(int id) onFlyDone;
  final Map<int, String> bubbles;
  final List<_FlyingCardEvent> dealCards;
  final void Function(int id) onDealCardDone;
  const _TableArea({
    required this.engine,
    required this.flys,
    required this.onFlyDone,
    required this.bubbles,
    required this.dealCards,
    required this.onDealCardDone,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final tableW = w * 0.82;
        final tableH = h * 0.75;
        final centerX = w / 2;
        final centerY = h / 2;

        final positions = _seatPositions(w, h);
        final actorSeat = engine.actorIdx;
        final reveal = engine.street == Street.handComplete ||
            engine.street == Street.showdown;

        final highlightMap = <Player, List<PlayingCard>>{};
        if (reveal && engine.lastShowdown.isNotEmpty) {
          for (final r in engine.lastShowdown) {
            highlightMap[r.player] = r.rank.bestFive;
          }
        }

        return Stack(
          children: [
            // Background halo — dark green radial behind the table.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 0.85,
                    colors: [
                      AppColors.tableHaloCenter,
                      AppColors.tableHaloEdge,
                    ],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),
            // Table: outer leather rim → felt → inner rail line.
            Center(
              child: _PokerTable(width: tableW, height: tableH),
            ),
            Positioned(
              left: centerX - 140,
              top: centerY - 80 - h * 0.20,
              width: 280,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.bgPanel,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      '팟 ${engine.pot}',
                      style: const TextStyle(
                        color: AppColors.highlight,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _CenterChipStack(pot: engine.pot),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.bgPanel,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          engine.street.label,
                          style: const TextStyle(
                            color: AppColors.accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.bgPanel,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Text(
                          'LV ${engine.tournamentLevel} · 앤티 ${engine.currentAnte}',
                          style: const TextStyle(
                            color: AppColors.highlight,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            for (var i = 0; i < engine.players.length; i++)
              Positioned(
                left: positions[i].dx - 81,
                top: positions[i].dy - 63,
                width: 162,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: PlayerSeat(
                    player: engine.players[i],
                    isActor: i == actorSeat &&
                        engine.street != Street.handComplete &&
                        engine.street != Street.showdown,
                    revealDownCards: reveal &&
                        engine.lastShowdown
                            .any((r) => r.player == engine.players[i]),
                    highlightCards: highlightMap[engine.players[i]] ?? const [],
                    badge: engine.players[i].isHuman
                        ? null
                        : AiPersonalityProfile.of(
                            engine.players[i].aiPersonality,
                          ).badge,
                  ),
                ),
              ),
            for (final ev in flys)
              _FlyingChip(
                key: ValueKey('fly_${ev.id}'),
                from: ev.fromCenter
                    ? Offset(
                        centerX + ((ev.id * 37) % 30) - 15,
                        centerY + ((ev.id * 53) % 20) - 10,
                      )
                    : positions[ev.seat],
                to: ev.fromCenter
                    ? positions[ev.seat]
                    : Offset(
                        centerX + ((ev.id * 37) % 40) - 20,
                        centerY + ((ev.id * 53) % 26) - 13,
                      ),
                color: ev.color,
                onDone: () => onFlyDone(ev.id),
              ),
            for (final ev in dealCards)
              _FlyingCard(
                key: ValueKey('dealcard_${ev.id}'),
                from: Offset(centerX, centerY),
                to: positions[ev.seat],
                onDone: () => onDealCardDone(ev.id),
              ),
            for (final entry in bubbles.entries)
              _speechBubbleOverlay(
                seatIdx: entry.key,
                seatPos: positions[entry.key],
                centerY: centerY,
                text: entry.value,
              ),
            if (actorSeat >= 0 &&
                engine.street != Street.handComplete &&
                engine.street != Street.showdown)
              _actorArrowOverlay(
                seatPos: positions[actorSeat],
                centerY: centerY,
              ),
            if (engine.showTurnCountdown &&
                actorSeat >= 0 &&
                engine.street != Street.handComplete &&
                engine.street != Street.showdown)
              _countdownOverlay(
                seatPos: positions[actorSeat],
                centerX: centerX,
                seconds: engine.turnSecondsRemaining,
              ),
            if (engine.street == Street.handComplete &&
                engine.lastShowdown.isNotEmpty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.center,
                    child: _ShowdownBanner(engine: engine),
                  ),
                ),
              ),
            if (_showThinkingOverlay())
              Positioned.fill(
                child: IgnorePointer(
                  child: Align(
                    alignment: Alignment.center,
                    child: Padding(
                      padding: EdgeInsets.only(top: h * 0.03),
                      child: _ThinkingOverlay(
                        label: engine.street == Street.showdown
                            ? '쇼다운…'
                            : '${engine.currentActor.name} 생각 중…',
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _showThinkingOverlay() {
    if (engine.street == Street.handComplete) return false;
    if (engine.declarationOpen) return false;
    if (engine.awaitingHumanAction) return false;
    if (engine.actorIdx < 0) return engine.street == Street.showdown;
    return true;
  }

  Widget _countdownOverlay({
    required Offset seatPos,
    required double centerX,
    required double seconds,
  }) {
    final side = seatPos.dx >= centerX ? 1 : -1;
    return Positioned(
      left: seatPos.dx + side * 130,
      top: seatPos.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: _CountdownBadge(secondsRemaining: seconds),
      ),
    );
  }

  Widget _speechBubbleOverlay({
    required int seatIdx,
    required Offset seatPos,
    required double centerY,
    required String text,
  }) {
    final pointingDown = seatPos.dy >= centerY;
    final top = pointingDown ? seatPos.dy - 175 : seatPos.dy + 95;
    return Positioned(
      left: seatPos.dx - 60,
      top: top,
      width: 120,
      child: IgnorePointer(
        child: Center(
          child: _SpeechBubble(text: text, pointingDown: pointingDown),
        ),
      ),
    );
  }

  Widget _actorArrowOverlay({
    required Offset seatPos,
    required double centerY,
  }) {
    final pointingDown = seatPos.dy >= centerY;
    final top = pointingDown ? seatPos.dy - 135 : seatPos.dy + 110;
    return Positioned(
      left: seatPos.dx - 40,
      top: top,
      child: _ActorArrow(pointingDown: pointingDown),
    );
  }

  List<Offset> _seatPositions(double w, double h) {
    final cx = w / 2;
    final cy = h / 2;
    final rx = w * 0.40;
    final ry = h * 0.40;

    // 5 seats evenly distributed on an ellipse, seat 0 at bottom.
    final positions = <Offset>[];
    for (var i = 0; i < 5; i++) {
      final angle = math.pi / 2 + (i * 2 * math.pi / 5);
      final x = cx + rx * math.cos(angle);
      var y = cy + ry * math.sin(angle);
      // 사람(seat 0)은 10% 위로, AI 4명은 7% 아래로 이동.
      if (i == 0) {
        y -= h * 0.10;
      } else {
        y += h * 0.07;
      }
      positions.add(Offset(x, y));
    }
    return positions;
  }
}

class _PokerTable extends StatelessWidget {
  final double width;
  final double height;
  const _PokerTable({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    // Outer leather rim thickness scales gently with table size.
    final rimThickness = (height * 0.07).clamp(12.0, 22.0);
    final innerRailInset = (height * 0.10).clamp(16.0, 32.0);
    final outerRadius = height / 2;
    final feltRadius = (height - rimThickness * 2) / 2;
    final railRadius = (height - rimThickness * 2 - innerRailInset * 2) / 2;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(outerRadius)),
        boxShadow: const [
          BoxShadow(
              color: Colors.black, blurRadius: 40, offset: Offset(0, 18)),
        ],
      ),
      child: Stack(
        children: [
          // Outer leather rim
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1a1c1f), AppColors.tableRim],
              ),
              borderRadius: BorderRadius.all(Radius.circular(outerRadius)),
            ),
          ),
          // Thin copper/gold inner edge where rim meets felt.
          Padding(
            padding: EdgeInsets.all(rimThickness - 2),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.circular(feltRadius + 2),
                ),
                border: Border.all(color: const Color(0xFFc08a4a), width: 1),
              ),
            ),
          ),
          // Felt (radial-gradient playing surface)
          Padding(
            padding: EdgeInsets.all(rimThickness),
            child: Container(
              decoration: BoxDecoration(
                gradient: const RadialGradient(
                  center: Alignment.center,
                  radius: 0.95,
                  colors: [
                    AppColors.feltCenter,
                    AppColors.feltMid,
                    AppColors.feltEdge,
                  ],
                  stops: [0.0, 0.7, 1.0],
                ),
                borderRadius: BorderRadius.all(Radius.circular(feltRadius)),
              ),
            ),
          ),
          // Inner rail line (the thin outline around the playing area)
          Padding(
            padding: EdgeInsets.all(rimThickness + innerRailInset),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.all(
                  Radius.circular(railRadius.clamp(0, railRadius)),
                ),
                border: Border.all(color: AppColors.feltRail, width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownBadge extends StatelessWidget {
  final double secondsRemaining;
  const _CountdownBadge({required this.secondsRemaining});

  @override
  Widget build(BuildContext context) {
    final s = secondsRemaining.ceil().clamp(0, 99);
    final Color textColor;
    if (s <= 3) {
      textColor = AppColors.danger;
    } else if (s <= 6) {
      textColor = AppColors.highlightSoft;
    } else {
      textColor = AppColors.highlight;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgPanel,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: textColor.withAlpha(120), width: 1.2),
      ),
      child: Text(
        '$s 초',
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w800,
          fontSize: 23,
        ),
      ),
    );
  }
}

class _CenterChipStack extends StatelessWidget {
  final int pot;
  const _CenterChipStack({required this.pot});

  static const _palette = <Color>[
    Color(0xFF1976d2), // blue
    Color(0xFFd32f2f), // red
    Color(0xFF388e3c), // green
    Color(0xFF212121), // black
    Color(0xFFf57c00), // orange
    Color(0xFF7b1fa2), // purple
    Color(0xFFfbc02d), // yellow
  ];

  @override
  Widget build(BuildContext context) {
    // ~10 chips per 100 of pot, capped so the zone stays readable.
    final total = (5 + pot / 10).clamp(5, 100).toInt();
    const chipW = 32.0;
    const chipH = 11.0;
    const chipStep = chipH * 0.38;
    const zoneW = 202.0;
    // Zone grows vertically when the pile gets tall, so stacks don't overflow.
    final zoneH = 100.0 + math.max(0, total - 20) * 0.55;

    final rng = math.Random(total);

    // Cluster sizes grow with total chip count so the pile visibly rises
    // (not just spreads horizontally) when the pot swells.
    final maxCluster = math.min(12, math.max(3, total ~/ 6));
    final clusterSizes = <int>[];
    var remaining = total;
    while (remaining > 0) {
      final maxChunk = math.min(remaining, maxCluster);
      final chunk = 1 + rng.nextInt(maxChunk);
      clusterSizes.add(chunk);
      remaining -= chunk;
    }

    // Assign a position to each cluster, with per-cluster y clamping so tall
    // stacks stay inside the zone and light collision avoidance on x.
    final positions = <Offset>[];
    for (var i = 0; i < clusterSizes.length; i++) {
      final size = clusterSizes[i];
      final stackTopOffset = (size - 1) * chipStep + chipH / 2;
      final yMin = stackTopOffset + 6;
      final yMax = zoneH - chipH / 2 - 4;
      Offset pos;
      var attempts = 0;
      do {
        final angle = rng.nextDouble() * 2 * math.pi;
        final r = math.sqrt(rng.nextDouble());
        final x = zoneW / 2 + math.cos(angle) * r * (zoneW * 0.40);
        var y = zoneH * 0.75 + math.sin(angle) * r * (zoneH * 0.22);
        y = y.clamp(yMin, yMax);
        pos = Offset(
          x.clamp(chipW / 2 + 2, zoneW - chipW / 2 - 2),
          y,
        );
        attempts++;
      } while (
          attempts < 14 &&
              positions.any((p) => (p - pos).distance < chipW * 0.42));
      positions.add(pos);
    }

    // Render back-to-front (small y first).
    final order = List.generate(clusterSizes.length, (i) => i)
      ..sort((a, b) => positions[a].dy.compareTo(positions[b].dy));

    final widgets = <Widget>[];

    // Soft floor shadow under the whole pile.
    widgets.add(Positioned(
      left: 8,
      right: 8,
      bottom: 2,
      height: 22,
      child: Container(
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.all(Radius.elliptical(120, 14)),
          gradient: RadialGradient(
            colors: [Colors.black54, Colors.transparent],
            stops: [0.0, 1.0],
          ),
        ),
      ),
    ));

    for (final idx in order) {
      final center = positions[idx];
      final size = clusterSizes[idx];
      for (var c = 0; c < size; c++) {
        final jitterX = rng.nextDouble() * 3 - 1.5;
        final jitterY = rng.nextDouble() * 1.5 - 0.5;
        final color = _palette[(idx * 2 + c) % _palette.length];
        widgets.add(Positioned(
          left: center.dx - chipW / 2 + jitterX,
          top: center.dy + jitterY - c * chipStep - chipH / 2,
          child: _ChipDisk(
            width: chipW,
            height: chipH,
            color: color,
          ),
        ));
      }
    }

    return SizedBox(
      width: zoneW,
      height: zoneH + chipH,
      child: Stack(clipBehavior: Clip.none, children: widgets),
    );
  }
}

class _ChipDisk extends StatelessWidget {
  final double width;
  final double height;
  final Color color;
  const _ChipDisk({
    required this.width,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _ChipPainter(color: color),
    );
  }
}

class _ChipPainter extends CustomPainter {
  final Color color;
  _ChipPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Chip geometry: top face ellipse + bottom face ellipse offset downward.
    // The visible crescent between them is the cylindrical side.
    final topH = h * 0.68; // top-face ellipse height
    final thickness = h - topH; // 2D perceived side thickness
    final topFaceRect = Rect.fromLTWH(0, 0, w, topH);
    final bottomFaceRect = Rect.fromLTWH(0, thickness, w, topH);

    final topLight = Color.lerp(color, Colors.white, 0.45)!;
    final topMid = color;
    final topRim = Color.lerp(color, Colors.black, 0.4)!;
    final sideMid = Color.lerp(color, Colors.black, 0.25)!;
    final sideDark = Color.lerp(color, Colors.black, 0.55)!;
    final stripeLight = Color.lerp(color, Colors.white, 0.75)!;
    final stripeDark = Color.lerp(color, Colors.black, 0.3)!;
    final darkRim = Color.lerp(color, Colors.black, 0.8)!;

    // Full silhouette: union of top and bottom ellipses.
    final silhouette = Path.combine(
      PathOperation.union,
      Path()..addOval(topFaceRect),
      Path()..addOval(bottomFaceRect),
    );

    // Drop shadow for the whole chip.
    canvas.drawPath(
      silhouette.shift(const Offset(0, 1.8)),
      Paint()
        ..color = Colors.black54
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
    );

    // Fill entire silhouette with the side gradient first — this paints the side band.
    canvas.drawPath(
      silhouette,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [sideMid, sideDark],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Draw stripes only on the visible side crescent (bottom ellipse minus top ellipse).
    final sideOnly = Path.combine(
      PathOperation.difference,
      Path()..addOval(bottomFaceRect),
      Path()..addOval(topFaceRect),
    );
    canvas.save();
    canvas.clipPath(sideOnly);
    const stripeCount = 12;
    for (var i = 0; i < stripeCount; i++) {
      final cx = w * ((i + 0.5) / stripeCount);
      final stripeW = w / stripeCount * 0.55;
      final stripeRect = Rect.fromLTWH(
        cx - stripeW / 2,
        thickness,
        stripeW,
        h - thickness,
      );
      canvas.drawRect(
        stripeRect,
        Paint()..color = i.isEven ? stripeLight : stripeDark,
      );
    }
    canvas.restore();

    // Top face — radial gradient simulating off-axis key light.
    canvas.drawOval(
      topFaceRect,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.55),
          radius: 1.0,
          colors: [topLight, topMid, topRim],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(topFaceRect),
    );

    // Top face specular shine (small bright crescent at upper-left).
    canvas.save();
    canvas.clipPath(Path()..addOval(topFaceRect));
    final shineRect = Rect.fromLTWH(
      w * 0.1,
      -topH * 0.15,
      w * 0.55,
      topH * 0.5,
    );
    canvas.drawOval(
      shineRect,
      Paint()..color = Colors.white.withAlpha(90),
    );
    canvas.restore();

    // Decorative inner ring on top face.
    final innerRect = Rect.fromCenter(
      center: topFaceRect.center,
      width: w * 0.52,
      height: topH * 0.42,
    );
    canvas.drawOval(
      innerRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = stripeLight.withAlpha(200),
    );

    // Seam where top face meets side.
    canvas.drawOval(
      topFaceRect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = Color.lerp(color, Colors.black, 0.45)!,
    );

    // Outer silhouette rim.
    canvas.drawPath(
      silhouette,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = darkRim,
    );
  }

  @override
  bool shouldRepaint(covariant _ChipPainter old) => old.color != color;
}

class _WinCelebration extends StatefulWidget {
  const _WinCelebration();

  @override
  State<_WinCelebration> createState() => _WinCelebrationState();
}

class _WinCelebrationState extends State<_WinCelebration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_Confetto> _confetti;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _confetti = List.generate(60, (_) {
      return _Confetto(
        angle: rng.nextDouble() * 2 * math.pi,
        distance: 160 + rng.nextDouble() * 260,
        size: 6 + rng.nextDouble() * 8,
        rotateSpeed: (rng.nextDouble() - 0.5) * 6,
        color: _palette[rng.nextInt(_palette.length)],
        drift: rng.nextDouble() * 0.4 - 0.2,
        startDelay: rng.nextDouble() * 0.25,
      );
    });
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3600),
    )..forward();
  }

  static const _palette = <Color>[
    AppColors.highlight,
    AppColors.accent,
    AppColors.danger,
    AppColors.highlightSoft,
    AppColors.info,
    Color(0xFFff6ec7),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cx = constraints.maxWidth / 2;
        final cy = constraints.maxHeight / 2;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final t = _ctrl.value;
            return Stack(
              children: [
                // Radial flash behind everything
                Positioned.fill(
                  child: Opacity(
                    opacity: (1 - t).clamp(0.0, 1.0) * 0.35,
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          colors: [
                            AppColors.highlight,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.7],
                        ),
                      ),
                    ),
                  ),
                ),
                // Confetti particles
                for (final c in _confetti) _paintConfetto(c, t, cx, cy),
                // WIN banner in center, fading out late
                Center(
                  child: Opacity(
                    opacity: _bannerOpacity(t),
                    child: Transform.scale(
                      scale: 0.6 + math.min(1.0, t * 4) * 0.6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.bgSunken.withAlpha(220),
                          borderRadius:
                              BorderRadius.circular(AppRadius.pill),
                          border: Border.all(
                              color: AppColors.highlight, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.highlight.withAlpha(180),
                              blurRadius: 40,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Text(
                          'WIN!',
                          style: TextStyle(
                            color: AppColors.highlight,
                            fontSize: 44,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  double _bannerOpacity(double t) {
    // Fade in quickly, hold, fade out at the end.
    if (t < 0.08) return t / 0.08;
    if (t > 0.8) return ((1 - t) / 0.2).clamp(0.0, 1.0);
    return 1.0;
  }

  Widget _paintConfetto(_Confetto c, double t, double cx, double cy) {
    final progress = ((t - c.startDelay) / (1 - c.startDelay)).clamp(0.0, 1.0);
    if (progress <= 0) return const SizedBox.shrink();
    final eased = Curves.easeOut.transform(progress);
    final r = c.distance * eased;
    final gravity = progress * progress * 120; // falls as time goes
    final x = cx + math.cos(c.angle) * r + c.drift * 100 * progress;
    final y = cy + math.sin(c.angle) * r + gravity;
    final rot = c.rotateSpeed * progress * math.pi;
    final fade = (1 - progress * progress).clamp(0.0, 1.0);
    return Positioned(
      left: x - c.size / 2,
      top: y - c.size / 2,
      child: Opacity(
        opacity: fade,
        child: Transform.rotate(
          angle: rot,
          child: Container(
            width: c.size,
            height: c.size * 0.5,
            decoration: BoxDecoration(
              color: c.color,
              borderRadius: BorderRadius.circular(2),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Confetto {
  final double angle;
  final double distance;
  final double size;
  final double rotateSpeed;
  final double drift;
  final double startDelay;
  final Color color;
  _Confetto({
    required this.angle,
    required this.distance,
    required this.size,
    required this.rotateSpeed,
    required this.drift,
    required this.startDelay,
    required this.color,
  });
}

class _ThinkingOverlay extends StatefulWidget {
  final String label;
  const _ThinkingOverlay({required this.label});

  @override
  State<_ThinkingOverlay> createState() => _ThinkingOverlayState();
}

class _ThinkingOverlayState extends State<_ThinkingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final alpha = (130 + 60 * _ctrl.value).toInt();
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.bgSunken.withAlpha(140),
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: AppColors.textPrimary.withAlpha(alpha),
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              shadows: const [
                Shadow(color: Colors.black, blurRadius: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FlyingCard extends StatefulWidget {
  final Offset from;
  final Offset to;
  final VoidCallback onDone;
  const _FlyingCard({
    super.key,
    required this.from,
    required this.to,
    required this.onDone,
  });

  @override
  State<_FlyingCard> createState() => _FlyingCardState();
}

class _FlyingCardState extends State<_FlyingCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_ctrl.value);
        final pos = Offset.lerp(widget.from, widget.to, t)!;
        final scale = 0.7 + t * 0.3;
        final opacity = (1 - t * t).clamp(0.0, 1.0);
        return Positioned(
          left: pos.dx - 18,
          top: pos.dy - 26,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: _MiniCardBack(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniCardBack extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 47,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.cardBackTop, AppColors.cardBackBottom],
        ),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: AppColors.accent.withAlpha(160), width: 1),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

class _SpeechBubble extends StatelessWidget {
  final String text;
  final bool pointingDown;
  const _SpeechBubble({required this.text, required this.pointingDown});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!pointingDown) _tail(flipped: false),
        Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.textPrimary,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 6),
            ],
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.bg,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ),
        if (pointingDown) _tail(flipped: true),
      ],
    );
  }

  Widget _tail({required bool flipped}) {
    return Transform.rotate(
      angle: flipped ? 0 : math.pi,
      child: CustomPaint(
        size: const Size(14, 8),
        painter: _TailPainter(),
      ),
    );
  }
}

class _TailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.textPrimary;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ActorArrow extends StatefulWidget {
  final bool pointingDown;
  const _ActorArrow({required this.pointingDown});

  @override
  State<_ActorArrow> createState() => _ActorArrowState();
}

class _ActorArrowState extends State<_ActorArrow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          final t = _ctrl.value;
          final scale = 1.0 + 0.15 * t;
          final bounceDir = widget.pointingDown ? -1 : 1;
          final bounce = math.sin(t * math.pi) * 5 * bounceDir;
          return Transform.translate(
            offset: Offset(0, bounce),
            child: Transform.scale(
              scale: scale,
              child: Icon(
                widget.pointingDown
                    ? Icons.arrow_drop_down
                    : Icons.arrow_drop_up,
                size: 64,
                color: AppColors.highlight,
                shadows: const [
                  Shadow(color: Colors.black, blurRadius: 10),
                  Shadow(color: AppColors.highlight, blurRadius: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FlyingChip extends StatefulWidget {
  final Offset from;
  final Offset to;
  final Color color;
  final VoidCallback onDone;
  const _FlyingChip({
    super.key,
    required this.from,
    required this.to,
    required this.color,
    required this.onDone,
  });

  @override
  State<_FlyingChip> createState() => _FlyingChipState();
}

class _FlyingChipState extends State<_FlyingChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    )
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_ctrl.value);
        final pos = Offset.lerp(widget.from, widget.to, t)!;
        // Arc: lift along an upward parabola.
        final lift = math.sin(t * math.pi) * 40;
        final rotation = t * math.pi;
        final opacity = (1 - t * t).clamp(0.0, 1.0);
        return Positioned(
          left: pos.dx - 21,
          top: pos.dy - lift - 8,
          child: IgnorePointer(
            child: Opacity(
              opacity: opacity,
              child: Transform.rotate(
                angle: rotation,
                child: _ChipDisk(
                  width: 40,
                  height: 14,
                  color: widget.color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ShowdownBanner extends StatelessWidget {
  final GameEngine engine;
  const _ShowdownBanner({required this.engine});

  @override
  Widget build(BuildContext context) {
    final winners =
        engine.lastShowdown.where((r) => r.winnings > 0).toList();
    if (winners.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.bgPanel,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.highlight, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final w in winners)
            Text(
              '${w.player.name} — ${w.rank.detailedLabel} (+${w.winnings})',
              style: const TextStyle(
                color: AppColors.highlight,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }
}

