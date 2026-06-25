/// In-app self-updater. The app is distributed off-Play-Store as APKs attached
/// to GitHub Releases; on launch we ask the Releases API for the latest version
/// and, if it's newer than what's running, offer a one-tap download + install
/// (see update_dialog.dart). All updates must be signed with the same release
/// key or Android refuses to install over the existing app.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// A newer release than the one currently installed.
class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.notes,
    required this.apkUrl,
  });

  /// Plain version string, e.g. "1.1.0" (leading "v" stripped).
  final String version;

  /// Release body / changelog, shown in the update dialog.
  final String notes;

  /// Direct download URL of the `.apk` asset on the release.
  final String apkUrl;
}

class UpdateService {
  const UpdateService();

  /// GitHub repo that hosts the releases. Must stay public so the API is
  /// readable without baking a token into the app.
  static const _owner = 'silham';
  static const _repo = 'pocket_ledger_app';

  static final _latestReleaseUrl =
      Uri.parse('https://api.github.com/repos/$_owner/$_repo/releases/latest');

  /// Returns the latest release if it's strictly newer than the running build,
  /// otherwise null. Never throws — any network/parse error means "no update".
  Future<AppUpdate?> checkForUpdate() async {
    try {
      final res = await http
          .get(_latestReleaseUrl, headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final latest = _stripV(json['tag_name'] as String? ?? '');
      if (latest.isEmpty) return null;

      final apkUrl = _firstApkUrl(json['assets'] as List<dynamic>?);
      if (apkUrl == null) return null;

      final current = (await PackageInfo.fromPlatform()).version;
      if (!_isNewer(latest, current)) return null;

      return AppUpdate(
        version: latest,
        notes: (json['body'] as String? ?? '').trim(),
        apkUrl: apkUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// Downloads the APK and hands off to Android's package installer. Emits
  /// progress events; the OS install screen takes over once the file lands.
  Stream<OtaEvent> download(String apkUrl) =>
      OtaUpdate().execute(apkUrl, destinationFilename: 'pocket-ledger-update.apk');

  static String _stripV(String tag) =>
      tag.startsWith('v') ? tag.substring(1) : tag;

  static String? _firstApkUrl(List<dynamic>? assets) {
    if (assets == null) return null;
    for (final asset in assets) {
      final map = asset as Map<String, dynamic>;
      final name = map['name'] as String? ?? '';
      if (name.toLowerCase().endsWith('.apk')) {
        return map['browser_download_url'] as String?;
      }
    }
    return null;
  }

  /// True if [candidate] is a higher semver than [current]. Compares the
  /// dot-separated numeric parts; missing parts count as 0.
  static bool _isNewer(String candidate, String current) {
    final a = _parts(candidate);
    final b = _parts(current);
    final len = a.length > b.length ? a.length : b.length;
    for (var i = 0; i < len; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  static List<int> _parts(String version) => version
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
}
