import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../ui/theme.dart';

/// Bump this on every APK release so the updater can compare versions.
/// It should match the tag you push to GitHub (minus the leading "v").
const kCurrentAppVersion = '1.0.3';

class UpdateService {
  static const _owner = 'leeseyoung77';
  static const _repo = 'poker_sy';

  /// Checks the GitHub Releases API for a newer version. If found and the
  /// dialog isn't already open, shows an update prompt.
  static Future<void> check(BuildContext context) async {
    if (kIsWeb) return;
    try {
      final res = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$_owner/$_repo/releases/latest',
            ),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (data['tag_name'] as String?)?.trim() ?? '';
      final clean = tag.startsWith('v') ? tag.substring(1) : tag;
      if (clean.isEmpty) return;
      if (!_isNewer(clean, kCurrentAppVersion)) return;
      final url = (data['html_url'] as String?) ?? '';
      final notes = (data['body'] as String?) ?? '';
      final apkUrl = _findApkUrl(data['assets']);
      if (context.mounted) {
        _showDialog(
          context,
          current: kCurrentAppVersion,
          latest: clean,
          releaseUrl: url,
          apkUrl: apkUrl,
          notes: notes,
        );
      }
    } catch (_) {
      // Silent failure (offline, repo not yet published, private repo, …).
    }
  }

  static String? _findApkUrl(dynamic assets) {
    if (assets is! List) return null;
    for (final a in assets) {
      if (a is Map<String, dynamic>) {
        final name = a['name'] as String?;
        if (name != null && name.toLowerCase().endsWith('.apk')) {
          return a['browser_download_url'] as String?;
        }
      }
    }
    return null;
  }

  /// Semver-ish comparison: major.minor.patch.
  static bool _isNewer(String latest, String current) {
    final l = latest.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final c = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    for (var i = 0; i < 3; i++) {
      final lv = i < l.length ? l[i] : 0;
      final cv = i < c.length ? c[i] : 0;
      if (lv > cv) return true;
      if (lv < cv) return false;
    }
    return false;
  }

  static void _showDialog(
    BuildContext context, {
    required String current,
    required String latest,
    required String releaseUrl,
    String? apkUrl,
    String notes = '',
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          '새 버전이 있어요',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '현재 $current  →  최신 $latest',
                style: const TextStyle(
                  color: AppColors.highlight,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '아래 주소를 브라우저에서 열어 APK를 받아 설치하세요.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 6),
              SelectableText(
                apkUrl ?? releaseUrl,
                style: const TextStyle(
                  color: AppColors.accent,
                  fontSize: 11,
                ),
              ),
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                  '변경 사항',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  notes,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('나중에'),
          ),
          ElevatedButton(
            onPressed: () async {
              await Clipboard.setData(
                ClipboardData(text: apkUrl ?? releaseUrl),
              );
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('업데이트 링크를 복사했습니다'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: AppColors.bg,
            ),
            child: const Text('링크 복사'),
          ),
        ],
      ),
    );
  }
}
