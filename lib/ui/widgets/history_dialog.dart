import 'package:flutter/material.dart';

import '../../game/game_engine.dart';
import '../theme.dart';

class HistoryDialog extends StatelessWidget {
  final GameEngine engine;
  const HistoryDialog({super.key, required this.engine});

  static Future<void> show(BuildContext context, GameEngine engine) {
    return showDialog<void>(
      context: context,
      builder: (_) => HistoryDialog(engine: engine),
    );
  }

  @override
  Widget build(BuildContext context) {
    final log = engine.log;
    return Dialog(
      backgroundColor: AppColors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '히스토리',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                Text(
                  engine.street.label,
                  style: const TextStyle(
                    color: AppColors.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
            const Divider(color: AppColors.border),
            SizedBox(
              height: 320,
              child: log.isEmpty
                  ? const Center(
                      child: Text(
                        '기록 없음',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      itemCount: log.length,
                      itemBuilder: (context, idx) {
                        final msg = log[log.length - 1 - idx];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Text(
                            msg,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
