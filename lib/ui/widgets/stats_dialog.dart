import 'package:flutter/material.dart';

import '../../game/game_stats.dart';
import '../theme.dart';

class StatsDialog extends StatelessWidget {
  final GameStats stats;
  const StatsDialog({super.key, required this.stats});

  static Future<void> show(BuildContext context, GameStats stats) {
    return showDialog<void>(
      context: context,
      builder: (_) => StatsDialog(stats: stats),
    );
  }

  @override
  Widget build(BuildContext context) {
    final winRate = stats.handsPlayed == 0
        ? 0.0
        : (stats.handsWon / stats.handsPlayed * 100);
    final all = Achievements.all;
    return Dialog(
      backgroundColor: AppColors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Container(
        width: 460,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '전적 · 업적',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
            const Divider(color: AppColors.border),
            const SizedBox(height: AppSpacing.sm),
            _statsRow('플레이 핸드', '${stats.handsPlayed}'),
            _statsRow('승리 핸드', '${stats.handsWon}'),
            _statsRow('승률', '${winRate.toStringAsFixed(1)}%'),
            _statsRow('누적 획득', '${stats.totalWinnings}'),
            _statsRow('최대 팟', '${stats.biggestPot}'),
            _statsRow('현재 연승', '${stats.currentStreak}'),
            _statsRow('최장 연승', '${stats.longestStreak}'),
            _statsRow('토너먼트 우승', '${stats.tournamentsWon}'),
            const SizedBox(height: AppSpacing.md),
            const Text(
              '업적',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 260),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final a in all)
                      _achievementRow(a, stats.unlocked.contains(a.id)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              )),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              )),
        ],
      ),
    );
  }

  Widget _achievementRow(Achievement a, bool unlocked) {
    return Opacity(
      opacity: unlocked ? 1.0 : 0.45,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              unlocked ? Icons.emoji_events : Icons.lock_outline,
              color:
                  unlocked ? AppColors.highlight : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      )),
                  Text(a.description,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
