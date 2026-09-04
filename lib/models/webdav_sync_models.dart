enum WebDavEndpoint { local, external }

extension WebDavEndpointLabel on WebDavEndpoint {
  String get label => switch (this) {
    WebDavEndpoint.local => '局域网 WebDAV',
    WebDavEndpoint.external => '外网 WebDAV',
  };
}

class WebDavConfig {
  const WebDavConfig({
    this.localUrl = '',
    this.externalUrl = '',
    this.username = '',
    this.password = '',
    this.autoSelectEndpoint = true,
  });

  final String localUrl;
  final String externalUrl;
  final String username;
  final String password;
  final bool autoSelectEndpoint;

  bool get isComplete =>
      (localUrl.trim().isNotEmpty || externalUrl.trim().isNotEmpty) &&
      username.trim().isNotEmpty &&
      password.isNotEmpty;

  String? urlFor(WebDavEndpoint endpoint) {
    final value = endpoint == WebDavEndpoint.local ? localUrl : externalUrl;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  List<WebDavEndpoint> get candidates {
    final configured = <WebDavEndpoint>[
      if (urlFor(WebDavEndpoint.local) != null) WebDavEndpoint.local,
      if (urlFor(WebDavEndpoint.external) != null) WebDavEndpoint.external,
    ];
    return autoSelectEndpoint || configured.length < 2
        ? configured
        : configured.take(1).toList();
  }

  WebDavConfig copyWith({
    String? localUrl,
    String? externalUrl,
    String? username,
    String? password,
    bool? autoSelectEndpoint,
  }) {
    return WebDavConfig(
      localUrl: localUrl ?? this.localUrl,
      externalUrl: externalUrl ?? this.externalUrl,
      username: username ?? this.username,
      password: password ?? this.password,
      autoSelectEndpoint: autoSelectEndpoint ?? this.autoSelectEndpoint,
    );
  }
}

class ConnectionTestResult {
  const ConnectionTestResult({
    required this.endpoint,
    required this.configured,
    required this.success,
    required this.message,
  });

  final WebDavEndpoint endpoint;
  final bool configured;
  final bool success;
  final String message;
}

enum SyncPhase {
  idle,
  selectingEndpoint,
  downloading,
  merging,
  uploading,
  restoring,
}

extension SyncPhaseLabel on SyncPhase {
  String get label => switch (this) {
    SyncPhase.idle => '尚未同步',
    SyncPhase.selectingEndpoint => '正在选择同步线路…',
    SyncPhase.downloading => '正在下载远端数据…',
    SyncPhase.merging => '正在合并账本数据…',
    SyncPhase.uploading => '正在上传同步结果…',
    SyncPhase.restoring => '正在从远端恢复数据…',
  };
}

class SyncResult {
  const SyncResult({
    required this.success,
    required this.message,
    this.endpoint,
  });

  final bool success;
  final String message;
  final WebDavEndpoint? endpoint;
}
