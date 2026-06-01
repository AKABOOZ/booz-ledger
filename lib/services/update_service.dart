import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class UpdateInfo {
  final String version;
  final String? body;
  final String? downloadUrl;

  const UpdateInfo({
    required this.version,
    this.body,
    this.downloadUrl,
  });
}

class UpdateService {
  static const _repoOwner = 'booz-ledger';
  static const _repoName = 'booz-ledger';
  static const _skippedVersionKey = 'skipped_update_version';
  static const _skippedDateKey = 'skipped_update_date';

  static Future<PackageInfo> getAppInfo() async {
    return await PackageInfo.fromPlatform();
  }

  static Future<String> getCurrentVersion() async {
    final info = await getAppInfo();
    return info.version;
  }

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest',
        ),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode != 200) {
        return null;
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String?;
      if (tagName == null || tagName.isEmpty) {
        return null;
      }

      final remoteVersion = tagName.replaceFirst('v', '');
      final currentVersion = await getCurrentVersion();

      if (!_isNewer(remoteVersion, currentVersion)) {
        return null;
      }

      // 检查是否今天已跳过
      final prefs = await SharedPreferences.getInstance();
      final skippedVersion = prefs.getString(_skippedVersionKey);
      final skippedDate = prefs.getString(_skippedDateKey);
      final today = DateTime.now().toIso8601String().substring(0, 10);

      if (skippedVersion == remoteVersion && skippedDate == today) {
        return null;
      }

      // 获取 APK 下载链接
      final assets = json['assets'] as List<dynamic>?;
      String? apkUrl;
      if (assets != null && assets.isNotEmpty) {
        for (final asset in assets) {
          final name = asset['name'] as String?;
          if (name != null && name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            break;
          }
        }
      }

      return UpdateInfo(
        version: remoteVersion,
        body: json['body'] as String?,
        downloadUrl: apkUrl,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> skipVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    await prefs.setString(_skippedVersionKey, version);
    await prefs.setString(_skippedDateKey, today);
  }

  static Future<void> downloadAndInstall(
    String url,
    String version,
    void Function(double progress)? onProgress,
  ) async {
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/booz-ledger-v$version.apk';
    final file = File(filePath);

    final request = await http.Client().send(http.Request('GET', Uri.parse(url)));
    final contentLength = request.headers['content-length'];
    final totalBytes = contentLength != null ? int.parse(contentLength) : 0;

    final bytes = <int>[];
    int receivedBytes = 0;

    await for (final chunk in request.stream) {
      bytes.addAll(chunk);
      receivedBytes += chunk.length;
      if (onProgress != null && totalBytes > 0) {
        onProgress(receivedBytes / totalBytes);
      }
    }

    await file.writeAsBytes(bytes);

    final result = await OpenFile.open(filePath);
    if (result.type != ResultType.done) {
      throw Exception('无法打开安装文件：${result.message}');
    }
  }

  static bool _isNewer(String remote, String current) {
    final remoteParts = remote.split('.');
    final currentParts = current.split('.');

    for (var i = 0; i < 3; i++) {
      final r = i < remoteParts.length ? int.tryParse(remoteParts[i]) ?? 0 : 0;
      final c = i < currentParts.length ? int.tryParse(currentParts[i]) ?? 0 : 0;
      if (r > c) return true;
      if (r < c) return false;
    }
    return false;
  }
}
