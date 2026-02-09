import 'dart:convert';
import 'package:http/http.dart' as http;

/// ejabberd REST API 客户端
///
/// 通过 mod_http_api 模块与 ejabberd 服务器交互
/// 主要用于 MUC 群聊管理功能
///
/// 需要在 ejabberd.yml 中配置:
/// ```yaml
/// listen:
///   -
///     port: 5280
///     module: ejabberd_http
///     request_handlers:
///       /api: mod_http_api
///
/// modules:
///   mod_http_api:
///     admin_ip_access: all
/// ```
class EjabberdApiClient {
  final String baseUrl;
  final String? adminUser;
  final String? adminPassword;

  EjabberdApiClient({
    required this.baseUrl,
    this.adminUser,
    this.adminPassword,
  });

  /// 获取 HTTP 请求头
  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (adminUser != null && adminPassword != null) {
      final credentials = base64Encode(utf8.encode('$adminUser:$adminPassword'));
      headers['Authorization'] = 'Basic $credentials';
    }

    return headers;
  }

  /// 发送 API 请求
  Future<dynamic> _request(String command, Map<String, dynamic> params) async {
    final url = Uri.parse('$baseUrl/api/$command');

    print('[EjabberdAPI] POST $url');
    print('[EjabberdAPI] Params: $params');

    try {
      final response = await http.post(
        url,
        headers: _headers,
        body: jsonEncode(params),
      );

      print('[EjabberdAPI] Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          return null;
        }
        return jsonDecode(response.body);
      } else {
        throw EjabberdApiException(
          'API request failed: ${response.statusCode}',
          response.statusCode,
          response.body,
        );
      }
    } catch (e) {
      if (e is EjabberdApiException) rethrow;
      throw EjabberdApiException('Network error: $e', 0, e.toString());
    }
  }

  // ============================================================================
  // MUC 群聊管理 API
  // ============================================================================

  /// 获取群聊成员列表（当前在线）
  ///
  /// 返回格式: [{jid, nick, role}, ...]
  Future<List<MucOccupant>> getRoomOccupants(String room, String service) async {
    final result = await _request('get_room_occupants', {
      'name': room,
      'service': service,
    });

    if (result == null || result is! List) return [];

    return (result as List).map((item) => MucOccupant.fromJson(item)).toList();
  }

  /// 获取群聊成员角色列表（包括离线成员）
  ///
  /// 返回格式: [{jid, affiliation, reason}, ...]
  Future<List<MucAffiliation>> getRoomAffiliations(
      String room, String service) async {
    final result = await _request('get_room_affiliations', {
      'name': room,
      'service': service,
    });

    if (result == null || result is! List) return [];

    return (result as List)
        .map((item) => MucAffiliation.fromJson(item))
        .toList();
  }

  /// 设置群成员角色
  ///
  /// [affiliation] 可选值: owner, admin, member, outcast, none
  /// - owner: 群主
  /// - admin: 管理员
  /// - member: 普通成员
  /// - outcast: 黑名单
  /// - none: 非成员（移除）
  ///
  /// 注意: ejabberd API 使用 name + service + jid 参数
  Future<void> setRoomAffiliation(
    String room,
    String service,
    String jid,
    String affiliation,
  ) async {
    await _request('set_room_affiliation', {
      'name': room,
      'service': service,
      'jid': jid,
      'affiliation': affiliation,
    });
  }

  /// 邀请用户加入群聊
  Future<void> sendDirectInvitation(
    String room,
    String service,
    String password,
    String reason,
    List<String> users,
  ) async {
    await _request('send_direct_invitation', {
      'room': '$room@$service',
      'password': password,
      'reason': reason,
      'users': users,
    });
  }

  /// 销毁群聊
  Future<void> destroyRoom(String room, String service,
      {String? reason}) async {
    await _request('destroy_room', {
      'name': room,
      'service': service,
    });
  }

  /// 修改群聊配置选项
  ///
  /// 常用选项:
  /// - title: 群名称
  /// - description: 群描述
  /// - public: 是否公开
  /// - persistent: 是否持久化
  /// - members_only: 仅限成员加入
  Future<void> changeRoomOption(
    String room,
    String service,
    String option,
    String value,
  ) async {
    await _request('change_room_option', {
      'name': room,
      'service': service,
      'option': option,
      'value': value,
    });
  }

  /// 获取群聊配置
  Future<Map<String, dynamic>> getRoomOptions(
      String room, String service) async {
    final result = await _request('get_room_options', {
      'name': room,
      'service': service,
    });

    if (result == null) return {};
    if (result is List) {
      // 转换 [{name, value}, ...] 为 Map
      final map = <String, dynamic>{};
      for (final item in result) {
        if (item is Map && item.containsKey('name')) {
          map[item['name']] = item['value'];
        }
      }
      return map;
    }
    return result as Map<String, dynamic>;
  }

  /// 创建群聊房间
  Future<void> createRoom(
    String room,
    String service,
    String host, {
    Map<String, dynamic>? options,
  }) async {
    await _request('create_room', {
      'name': room,
      'service': service,
      'host': host,
    });

    // 设置初始配置
    if (options != null) {
      for (final entry in options.entries) {
        await changeRoomOption(room, service, entry.key, entry.value.toString());
      }
    }
  }

  /// 获取 MUC 服务列表
  Future<List<String>> getMucServices(String host) async {
    final result = await _request('muc_online_rooms', {
      'host': host,
    });

    if (result == null || result is! List) return [];
    return List<String>.from(result);
  }

  // ============================================================================
  // 用户管理 API
  // ============================================================================

  /// 检查用户是否存在
  Future<bool> checkAccount(String user, String host) async {
    try {
      final result = await _request('check_account', {
        'user': user,
        'host': host,
      });
      return result == 0;
    } catch (e) {
      return false;
    }
  }

  /// 获取用户的 VCard
  Future<Map<String, dynamic>?> getVcard(String user, String host) async {
    try {
      final result = await _request('get_vcard', {
        'user': user,
        'host': host,
      });
      return result as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  /// 获取所有注册用户
  ///
  /// 返回用户名列表（不包含域名）
  Future<List<String>> getRegisteredUsers(String host) async {
    try {
      final result = await _request('registered_users', {
        'host': host,
      });

      if (result == null || result is! List) return [];
      return List<String>.from(result);
    } catch (e) {
      print('[EjabberdAPI] 获取注册用户失败: $e');
      return [];
    }
  }
}

/// MUC 在线成员信息
class MucOccupant {
  final String jid;
  final String nick;
  final String role;

  MucOccupant({
    required this.jid,
    required this.nick,
    required this.role,
  });

  factory MucOccupant.fromJson(Map<String, dynamic> json) {
    return MucOccupant(
      jid: json['jid'] ?? '',
      nick: json['nick'] ?? '',
      role: json['role'] ?? 'participant',
    );
  }
}

/// MUC 成员角色信息
class MucAffiliation {
  final String jid;
  final String affiliation;
  final String? reason;

  MucAffiliation({
    required this.jid,
    required this.affiliation,
    this.reason,
  });

  factory MucAffiliation.fromJson(Map<String, dynamic> json) {
    // ejabberd 返回格式可能是 {username, domain, affiliation, reason}
    String jid;
    if (json.containsKey('jid')) {
      jid = json['jid'];
    } else if (json.containsKey('username') && json.containsKey('domain')) {
      jid = '${json['username']}@${json['domain']}';
    } else {
      jid = '';
    }

    return MucAffiliation(
      jid: jid,
      affiliation: json['affiliation'] ?? 'member',
      reason: json['reason'],
    );
  }

  bool get isOwner => affiliation == 'owner';
  bool get isAdmin => affiliation == 'admin';
  bool get isMember => affiliation == 'member';
  bool get isOutcast => affiliation == 'outcast';
}

/// ejabberd API 异常
class EjabberdApiException implements Exception {
  final String message;
  final int statusCode;
  final String? body;

  EjabberdApiException(this.message, this.statusCode, this.body);

  @override
  String toString() => 'EjabberdApiException: $message (status: $statusCode)';
}
