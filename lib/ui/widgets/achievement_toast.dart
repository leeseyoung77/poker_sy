import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/game_stats.dart';
import '../theme.dart';

class AchievementToastController {
  final List<Achievement> _queue = [];
  Achievement? _current;
  final void Function(Achievement?) _setter;
  Timer? _timer;

  AchievementToastController(this._setter);

  void enqueue(Iterable<Achievement> items) {
    _queue.addAll(items);
    _showNextIfIdle();
  }

  void _showNextIfIdle() {
    if (_current != null) return;
    if (_queue.isEmpty) return;
    _current = _queue.removeAt(0);
    _setter(_current);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 3), () {
      _current = null;
      _setter(null);
      if (_queue.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 250), _showNextIfIdle);
      }
    });
  }

  void dispose() {
    _timer?.cancel();
  }
}

class AchievementToast extends StatelessWidget {
  final Achievement achievement;
  const AchievementToast({super.key, required this.achievement});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSunken,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.highlight, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.highlight.withAlpha(80),
            blurRadius: 24,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.emoji_events_rounded,
            color: AppColors.highlight,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '업적 달성',
                style: TextStyle(
                  color: AppColors.highlight,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                achievement.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                achievement.description,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
