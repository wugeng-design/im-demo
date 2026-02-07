/// IM SDK 连接配置
///
/// 用于配置 XMPP 服务器连接参数
///
/// 使用示例：
/// ```dart
/// final config = ImSdkConfig(
///   host: 'localhost',
///   port: 5222,
///   domain: 'localhost',
/// );
/// ```
class ImSdkConfig {
  /// XMPP 服务器地址
  final String host;

  /// XMPP 服务器端口（默认 5222）
  final int port;

  /// XMPP 域名
  final String domain;

  /// MUC（群聊）服务域名
  final String mucDomain;

  /// 是否使用 TLS
  final bool useTls;

  /// 连接超时时间（毫秒）
  final int connectTimeout;

  /// 是否自动重连
  final bool autoReconnect;

  /// 重连间隔（毫秒）
  final int reconnectInterval;

  /// 最大重连次数（0 表示无限）
  final int maxReconnectAttempts;

  /// 心跳间隔（秒）
  final int pingInterval;

  /// 资源标识（用于多设备）
  final String resource;

  const ImSdkConfig({
    required this.host,
    this.port = 5222,
    required this.domain,
    String? mucDomain,
    this.useTls = false,
    this.connectTimeout = 30000,
    this.autoReconnect = true,
    this.reconnectInterval = 5000,
    this.maxReconnectAttempts = 0,
    this.pingInterval = 60,
    this.resource = 'flutter',
  }) : mucDomain = mucDomain ?? 'conference.$domain';

  /// 本地开发配置（连接本地 ejabberd）
  factory ImSdkConfig.localhost() {
    return const ImSdkConfig(
      host: 'localhost',
      port: 5222,
      domain: 'localhost',
      useTls: false,
    );
  }

  /// conversations.im 公共服务器配置
  /// 使用 STARTTLS (useTls=false)，不是 DirectTLS
  factory ImSdkConfig.conversationsIm() {
    return const ImSdkConfig(
      host: 'conversations.im',
      port: 5222,
      domain: 'conversations.im',
      useTls: false, // STARTTLS，不是 DirectTLS
    );
  }

  /// jabber.de 公共服务器配置
  /// 使用 STARTTLS (useTls=false)，不是 DirectTLS
  factory ImSdkConfig.jabberDe() {
    return const ImSdkConfig(
      host: 'jabber.de',
      port: 5222,
      domain: 'jabber.de',
      useTls: false, // STARTTLS，不是 DirectTLS
    );
  }

  /// 从 JSON 创建
  factory ImSdkConfig.fromJson(Map<String, dynamic> json) {
    return ImSdkConfig(
      host: json['host'] as String,
      port: json['port'] as int? ?? 5222,
      domain: json['domain'] as String,
      mucDomain: json['mucDomain'] as String?,
      useTls: json['useTls'] as bool? ?? false,
      connectTimeout: json['connectTimeout'] as int? ?? 30000,
      autoReconnect: json['autoReconnect'] as bool? ?? true,
      reconnectInterval: json['reconnectInterval'] as int? ?? 5000,
      maxReconnectAttempts: json['maxReconnectAttempts'] as int? ?? 0,
      pingInterval: json['pingInterval'] as int? ?? 60,
      resource: json['resource'] as String? ?? 'flutter',
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'host': host,
      'port': port,
      'domain': domain,
      'mucDomain': mucDomain,
      'useTls': useTls,
      'connectTimeout': connectTimeout,
      'autoReconnect': autoReconnect,
      'reconnectInterval': reconnectInterval,
      'maxReconnectAttempts': maxReconnectAttempts,
      'pingInterval': pingInterval,
      'resource': resource,
    };
  }

  /// 复制并修改
  ImSdkConfig copyWith({
    String? host,
    int? port,
    String? domain,
    String? mucDomain,
    bool? useTls,
    int? connectTimeout,
    bool? autoReconnect,
    int? reconnectInterval,
    int? maxReconnectAttempts,
    int? pingInterval,
    String? resource,
  }) {
    return ImSdkConfig(
      host: host ?? this.host,
      port: port ?? this.port,
      domain: domain ?? this.domain,
      mucDomain: mucDomain ?? this.mucDomain,
      useTls: useTls ?? this.useTls,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      reconnectInterval: reconnectInterval ?? this.reconnectInterval,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
      pingInterval: pingInterval ?? this.pingInterval,
      resource: resource ?? this.resource,
    );
  }

  @override
  String toString() => 'ImSdkConfig(host: $host, port: $port, domain: $domain)';
}

/// 用户认证凭据
class ImCredentials {
  /// 用户名（JID 的 localpart）
  final String username;

  /// 密码
  final String password;

  /// 完整 JID（自动生成）
  String get jid => '$username@${_domain ?? "localhost"}';

  final String? _domain;

  const ImCredentials({
    required this.username,
    required this.password,
    String? domain,
  }) : _domain = domain;

  /// 带域名的凭据
  ImCredentials withDomain(String domain) {
    return ImCredentials(
      username: username,
      password: password,
      domain: domain,
    );
  }

  @override
  String toString() => 'ImCredentials(username: $username)';
}
