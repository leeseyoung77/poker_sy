import 'package:flutter/material.dart';

import '../../audio/sfx.dart';
import '../theme.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const SettingsDialog(),
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late double _volume = Sfx.volume;
  late bool _muted = Sfx.muted;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '설정',
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
            const Text(
              '사운드',
              style: TextStyle(
                color: AppColors.accent,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _muted = !_muted;
                      Sfx.muted = _muted;
                    });
                  },
                  icon: Icon(
                    _muted ? Icons.volume_off : Icons.volume_up,
                    color: _muted
                        ? AppColors.textMuted
                        : AppColors.accent,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label: '${(_volume * 100).round()}%',
                    onChanged: _muted
                        ? null
                        : (v) {
                            setState(() {
                              _volume = v;
                              Sfx.volume = v;
                            });
                          },
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    _muted ? '음소거' : '${(_volume * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: () {
                Sfx.playFanfare();
              },
              icon: const Icon(Icons.play_arrow,
                  color: AppColors.accent),
              label: const Text(
                '효과음 미리 듣기',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
