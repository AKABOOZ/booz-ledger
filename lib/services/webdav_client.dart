import 'dart:async';

import 'package:http/http.dart' as http;

class WebDavException implements Exception {
  const WebDavException(this.message);
  final String message;
  @override
  String toString() => message;
}

class WebDavFileInfo {
  const WebDavFileInfo({required this.name, this.modifiedAt, this.size});
  final String name;
  final DateTime? modifiedAt;
  final int? size;
}

class WebDavClient {
  WebDavClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> verifyDirectory(
    Uri directory,
    String authorization, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final response = await _request(
      'PROPFIND',
      directory,
      authorization,
      headers: const {
        'Depth': '0',
        'Content-Type': 'application/xml; charset=utf-8',
      },
      body: _propfindBody,
      timeout: timeout,
    );
    if (response.statusCode == 404) {
      final create = await _request(
        'MKCOL',
        directory,
        authorization,
        timeout: timeout,
      );
      if (create.statusCode != 201 && create.statusCode != 405) {
        throw _errorForStatus(create.statusCode);
      }
      return verifyDirectory(directory, authorization, timeout: timeout);
    }
    if (response.statusCode != 207 || !_isMultiStatus(response.body)) {
      throw response.statusCode >= 200 && response.statusCode < 300
          ? const WebDavException('服务器响应不是有效的 WebDAV 目录')
          : _errorForStatus(response.statusCode);
    }
  }

  Future<List<WebDavFileInfo>> list(Uri directory, String authorization) async {
    final response = await _request(
      'PROPFIND',
      directory,
      authorization,
      headers: const {
        'Depth': '1',
        'Content-Type': 'application/xml; charset=utf-8',
      },
      body: _propfindBody,
      timeout: const Duration(seconds: 30),
    );
    if (response.statusCode != 207 || !_isMultiStatus(response.body)) {
      throw response.statusCode >= 200 && response.statusCode < 300
          ? const WebDavException('服务器响应不是有效的 WebDAV 目录')
          : _errorForStatus(response.statusCode);
    }
    return _parseFiles(response.body, directory);
  }

  Future<String> download(Uri file, String authorization) async {
    final response = await _request(
      'GET',
      file,
      authorization,
      timeout: const Duration(seconds: 30),
    );
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.body.isEmpty) {
      throw response.statusCode >= 200 && response.statusCode < 300
          ? const WebDavException('下载的备份文件为空')
          : _errorForStatus(response.statusCode);
    }
    return response.body;
  }

  Future<void> upload(
    Uri file,
    String authorization,
    String body, {
    String contentType = 'application/json',
  }) async {
    final response = await _request(
      'PUT',
      file,
      authorization,
      headers: {'Content-Type': contentType},
      body: body,
      timeout: const Duration(seconds: 60),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorForStatus(response.statusCode);
    }
  }

  Future<void> delete(Uri file, String authorization) async {
    final response = await _request(
      'DELETE',
      file,
      authorization,
      timeout: const Duration(seconds: 30),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _errorForStatus(response.statusCode);
    }
  }

  Future<void> writeAndDeleteProbe(Uri directory, String authorization) async {
    final name = '.ledger-probe-${DateTime.now().microsecondsSinceEpoch}.tmp';
    final uri = directory.resolve(Uri.encodeComponent(name));
    await upload(uri, authorization, 'ok', contentType: 'text/plain');
    await delete(uri, authorization);
  }

  Future<http.Response> _request(
    String method,
    Uri uri,
    String authorization, {
    Map<String, String> headers = const {},
    String? body,
    required Duration timeout,
  }) async {
    try {
      final request = http.Request(method, uri)
        ..headers.addAll({'Authorization': authorization, ...headers});
      if (body != null) {
        request.body = body;
      }
      final streamed = await _client.send(request).timeout(timeout);
      return http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const WebDavException('连接 NAS 超时，请检查网络或 WebDAV 地址');
    } catch (_) {
      throw const WebDavException('连接 NAS 超时，请检查网络或 WebDAV 地址');
    }
  }

  WebDavException _errorForStatus(int status) => switch (status) {
    401 => const WebDavException('认证失败，请检查账号和密码'),
    403 => const WebDavException('没有权限访问该目录'),
    404 => const WebDavException('备份目录不存在，请检查 WebDAV 路径'),
    _ => WebDavException('服务器返回 $status'),
  };

  bool _isMultiStatus(String body) => RegExp(
    r'<(?:[\w-]+:)?multistatus\b',
    caseSensitive: false,
  ).hasMatch(body);

  List<WebDavFileInfo> _parseFiles(String body, Uri directory) {
    final responses = RegExp(
      r'<(?:[\w-]+:)?response\b[^>]*>([\s\S]*?)</(?:[\w-]+:)?response>',
      caseSensitive: false,
    ).allMatches(body);
    final result = <WebDavFileInfo>[];
    for (final response in responses) {
      final item = response.group(1) ?? '';
      final href = RegExp(
        r'<(?:[\w-]+:)?href\b[^>]*>([^<]+)</(?:[\w-]+:)?href>',
        caseSensitive: false,
      ).firstMatch(item)?.group(1);
      if (href == null) {
        continue;
      }
      final uri =
          Uri.tryParse(href.replaceAll('&amp;', '&')) ??
          directory.resolve(href);
      final name = uri.pathSegments.where((part) => part.isNotEmpty).lastOrNull;
      if (name == null ||
          name ==
              directory.pathSegments
                  .where((part) => part.isNotEmpty)
                  .lastOrNull) {
        continue;
      }
      final modifiedText = RegExp(
        r'<(?:[\w-]+:)?getlastmodified\b[^>]*>([^<]+)',
        caseSensitive: false,
      ).firstMatch(item)?.group(1);
      final sizeText = RegExp(
        r'<(?:[\w-]+:)?getcontentlength\b[^>]*>([^<]+)',
        caseSensitive: false,
      ).firstMatch(item)?.group(1);
      result.add(
        WebDavFileInfo(
          name: name,
          modifiedAt: modifiedText == null
              ? null
              : DateTime.tryParse(modifiedText),
          size: int.tryParse(sizeText ?? ''),
        ),
      );
    }
    return result;
  }

  static const _propfindBody = '''<?xml version="1.0" encoding="utf-8"?>
<d:propfind xmlns:d="DAV:"><d:prop><d:getlastmodified/><d:getcontentlength/></d:prop></d:propfind>''';
}

extension on Iterable<String> {
  String? get lastOrNull => isEmpty ? null : last;
}
