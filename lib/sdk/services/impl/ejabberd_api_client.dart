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

  /// 设置用户的 vCard 字段
  ///
  /// 使用 ejabberd REST API 的 set_vcard2 命令
  ///
  /// [user] 用户名（不含域名）
  /// [host] 域名
  /// [name] vCard 字段名，支持以下字段：
  ///   - NICKNAME: 昵称
  ///   - FN: 全名
  ///   - PHOTO EXTVAL: 头像 URL（外部链接）
  ///   - PHOTO TYPE: 头像 MIME 类型
  /// [content] 字段值
  Future<void> setVcard2(
    String user,
    String host,
    String name,
    String content,
  ) async {
    await _request('set_vcard2', {
      'user': user,
      'host': host,
      'name': name,
      'content': content,
    });
  }

  /// 便捷方法：设置用户头像 URL
  ///
  /// 将头像 URL 存储到 vCard 的 PHOTO EXTVAL 字段
  Future<void> setUserAvatarUrl(
    String user,
    String host,
    String avatarUrl,
  ) async {
    // 设置头像 URL
    await setVcard2(user, host, 'PHOTO EXTVAL', avatarUrl);
    // 设置头像类型
    final mimeType = _getMimeTypeFromUrl(avatarUrl);
    await setVcard2(user, host, 'PHOTO TYPE', mimeType);
  }

  /// 从 URL 推断 MIME 类型
  String _getMimeTypeFromUrl(String url) {
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.endsWith('.png')) return 'image/png';
    if (lowerUrl.endsWith('.gif')) return 'image/gif';
    if (lowerUrl.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg'; // 默认 JPEG
  }

  /// 设置群聊头像
  ///
  /// 通过 room option 存储群头像 URL
  Future<void> setRoomAvatar(
    String room,
    String service,
    String avatarUrl,
  ) async {
    await changeRoomOption(room, service, 'vcard_photo', avatarUrl);
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

  // ============================================================================
  // 用户注册和密码管理 API
  // ============================================================================

  /// 注册新用户
  ///
  /// [user] 用户名（不含域名）
  /// [host] 域名
  /// [password] 密码
  Future<void> register(String user, String host, String password) async {
    await _request('register', {
      'user': user,
      'host': host,
      'password': password,
    });
  }

  /// 注销用户
  ///
  /// [user] 用户名（不含域名）
  /// [host] 域名
  Future<void> unregister(String user, String host) async {
    await _request('unregister', {
      'user': user,
      'host': host,
    });
  }

  /// 修改用户密码
  ///
  /// [user] 用户名（不含域名）
  /// [host] 域名
  /// [newPassword] 新密码
  Future<void> changePassword(String user, String host, String newPassword) async {
    await _request('change_password', {
      'user': user,
      'host': host,
      'newpass': newPassword,
    });
  }

  // ============================================================================
  // 好友/花名册管理 API
  // ============================================================================

  /// 获取用户的好友列表
  ///
  /// 返回好友 JID 列表
  Future<List<RosterItem>> getRoster(String user, String host) async {
    try {
      final result = await _request('get_roster', {
        'user': user,
        'host': host,
      });

      if (result == null || result is! List) return [];
      return result.map((item) => RosterItem.fromJson(item as Map<String, dynamic>)).toList();
    } catch (e) {
      print('[EjabberdAPI] 获取好友列表失败: $e');
      return [];
    }
  }

  /// 添加好友
  ///
  /// [localUser] 本地用户名
  /// [localHost] 本地域名
  /// [contactJid] 好友 JID
  /// [nick] 好友昵称
  /// [groups] 分组列表
  /// [subscription] 订阅类型 (none, from, to, both)
  Future<void> addRosterItem(
    String localUser,
    String localHost,
    String contactJid,
    String nick, {
    List<String>? groups,
    String subscription = 'both',
  }) async {
    await _request('add_rosteritem', {
      'localuser': localUser,
      'localhost': localHost,
      'user': contactJid.split('@').first,
      'host': contactJid.contains('@') ? contactJid.split('@').last : localHost,
      'nick': nick,
      'group': groups?.join(',') ?? '',
      'subs': subscription,
    });
  }

  /// 删除好友
  ///
  /// [localUser] 本地用户名
  /// [localHost] 本地域名
  /// [contactJid] 好友 JID
  Future<void> deleteRosterItem(
    String localUser,
    String localHost,
    String contactJid,
  ) async {
    await _request('delete_rosteritem', {
      'localuser': localUser,
      'localhost': localHost,
      'user': contactJid.split('@').first,
      'host': contactJid.contains('@') ? contactJid.split('@').last : localHost,
    });
  }

  // ============================================================================
  // 用户群聊查询 API
  // ============================================================================

  /// 获取用户加入的所有群聊
  ///
  /// 返回群聊 JID 列表
  Future<List<String>> getUserRooms(String user, String host) async {
    try {
      final result = await _request('get_user_rooms', {
        'user': user,
        'host': host,
      });

      if (result == null || result is! List) return [];
      return List<String>.from(result);
    } catch (e) {
      print('[EjabberdAPI] 获取用户群聊列表失败: $e');
      return [];
    }
  }

  // ============================================================================
  // 消息和状态 API
  // ============================================================================

  /// 获取用户离线消息数量
  Future<int> getOfflineCount(String user, String host) async {
    try {
      final result = await _request('get_offline_count', {
        'user': user,
        'host': host,
      });
      return result is int ? result : 0;
    } catch (e) {
      print('[EjabberdAPI] 获取离线消息数量失败: $e');
      return 0;
    }
  }

  /// 获取用户最后活动时间
  ///
  /// 返回: {status: "状态", timestamp: 时间戳}
  Future<Map<String, dynamic>?> getLastActivity(String user, String host) async {
    try {
      final result = await _request('get_last', {
        'user': user,
        'host': host,
      });
      return result as Map<String, dynamic>?;
    } catch (e) {
      print('[EjabberdAPI] 获取最后活动时间失败: $e');
      return null;
    }
  }

  /// 从服务端发送消息
  ///
  /// [type] 消息类型: chat, headline, groupchat
  /// [from] 发送者 JID
  /// [to] 接收者 JID
  /// [subject] 主题（可选）
  /// [body] 消息内容
  Future<void> sendMessage({
    required String type,
    required String from,
    required String to,
    String? subject,
    required String body,
  }) async {
    await _request('send_message', {
      'type': type,
      'from': from,
      'to': to,
      'subject': subject ?? '',
      'body': body,
    });
  }

  /// 发送系统通知给所有用户
  ///
  /// [host] 域名
  /// [subject] 主题
  /// [body] 内容
  Future<void> sendBroadcastMessage(String host, String subject, String body) async {
    await _request('send_stanza_c2s', {
      'host': host,
      'stanza': '<message type="headline"><subject>$subject</subject><body>$body</body></message>',
    });
  }

  // ============================================================================
  // 服务器状态 API
  // ============================================================================

  /// 获取在线用户数
  Future<int> getConnectedUsersNumber() async {
    try {
      final result = await _request('connected_users_number', {});
      return result is int ? result : 0;
    } catch (e) {
      print('[EjabberdAPI] 获取在线用户数失败: $e');
      return 0;
    }
  }

  /// 获取服务器统计信息
  ///
  /// [name] 统计项名称: registeredusers, onlineusers, onlineusersnode, uptimeseconds
  Future<int> getStats(String name) async {
    try {
      final result = await _request('stats', {
        'name': name,
      });
      return result is int ? result : 0;
    } catch (e) {
      print('[EjabberdAPI] 获取统计信息失败: $e');
      return 0;
    }
  }

  // ============================================================================
  // 扩展 API（需服务端实现）
  // ============================================================================

  /// 搜索用户
  ///
  /// [host] 域名
  /// [keyword] 搜索关键词
  /// [limit] 返回数量限制
  Future<List<SearchUserResult>> searchUsers(
    String host,
    String keyword, {
    int limit = 20,
  }) async {
    try {
      final result = await _request('search_users', {
        'host': host,
        'keyword': keyword,
        'limit': limit,
      });

      if (result == null || result is! List) return [];
      return result
          .map((item) => SearchUserResult.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[EjabberdAPI] 搜索用户失败: $e');
      return [];
    }
  }

  /// 批量获取用户在线状态
  Future<List<UserPresence>> getUsersPresence(List<String> users) async {
    try {
      final result = await _request('get_users_presence', {
        'users': users,
      });

      if (result == null || result is! List) return [];
      return result
          .map((item) => UserPresence.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('[EjabberdAPI] 获取在线状态失败: $e');
      return [];
    }
  }

  /// 撤回消息
  Future<void> recallMessage({
    required String from,
    required String to,
    required String messageId,
  }) async {
    await _request('recall_message', {
      'from': from,
      'to': to,
      'message_id': messageId,
    });
  }

  /// 标记消息已读
  Future<void> markAsRead({
    required String user,
    required String host,
    required String peer,
    String? upToId,
  }) async {
    await _request('mark_as_read', {
      'user': user,
      'host': host,
      'peer': peer,
      if (upToId != null) 'up_to_id': upToId,
    });
  }

  /// 设置群公告
  Future<void> setRoomAnnouncement({
    required String room,
    required String service,
    required String announcement,
    String? sender,
  }) async {
    await _request('set_room_announcement', {
      'name': room,
      'service': service,
      'announcement': announcement,
      if (sender != null) 'sender': sender,
    });
  }

  /// 获取群公告
  Future<String?> getRoomAnnouncement(String room, String service) async {
    try {
      final options = await getRoomOptions(room, service);
      return options['announcement'] as String?;
    } catch (e) {
      return null;
    }
  }
}

/// 用户搜索结果
class SearchUserResult {
  final String jid;
  final String? nickname;
  final String? avatar;

  SearchUserResult({
    required this.jid,
    this.nickname,
    this.avatar,
  });

  factory SearchUserResult.fromJson(Map<String, dynamic> json) {
    return SearchUserResult(
      jid: json['jid'] ?? '',
      nickname: json['nickname'],
      avatar: json['avatar'],
    );
  }

  String get displayName => nickname ?? jid.split('@').first;
}

/// 用户在线状态
class UserPresence {
  final String jid;
  final bool online;
  final String? show;
  final int? lastSeen;

  UserPresence({
    required this.jid,
    required this.online,
    this.show,
    this.lastSeen,
  });

  factory UserPresence.fromJson(Map<String, dynamic> json) {
    return UserPresence(
      jid: json['jid'] ?? '',
      online: json['online'] ?? false,
      show: json['show'],
      lastSeen: json['last_seen'],
    );
  }

  String get statusText {
    if (!online) {
      if (lastSeen != null) {
        final dt = DateTime.fromMillisecondsSinceEpoch(lastSeen! * 1000);
        final now = DateTime.now();
        final diff = now.difference(dt);
        if (diff.inMinutes < 60) {
          return '${diff.inMinutes}分钟前在线';
        } else if (diff.inHours < 24) {
          return '${diff.inHours}小时前在线';
        } else {
          return '${diff.inDays}天前在线';
        }
      }
      return '离线';
    }
    switch (show) {
      case 'away':
        return '离开';
      case 'xa':
        return '忙碌';
      case 'dnd':
        return '勿扰';
      default:
        return '在线';
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

/// 好友/花名册项
class RosterItem {
  final String jid;
  final String? nick;
  final String subscription;
  final List<String> groups;

  RosterItem({
    required this.jid,
    this.nick,
    required this.subscription,
    this.groups = const [],
  });

  factory RosterItem.fromJson(Map<String, dynamic> json) {
    return RosterItem(
      jid: json['jid'] ?? '',
      nick: json['nick'],
      subscription: json['subscription'] ?? 'none',
      groups: json['group'] is List
          ? List<String>.from(json['group'])
          : (json['group'] as String?)?.split(',').where((g) => g.isNotEmpty).toList() ?? [],
    );
  }

  bool get isFriend => subscription == 'both';
  bool get isPending => subscription == 'none' || subscription == 'from';
}

/// ejabberd API 异常
class EjabberdApiException implements Exception {
  final String message;
  final int statusCode;
  final String? body;

  EjabberdApiException(this.message, this.statusCode, this.body);

  @override
  String toString() {
    if (body != null && body!.isNotEmpty) {
      return 'EjabberdApiException: $message (status: $statusCode, body: $body)';
    }
    return 'EjabberdApiException: $message (status: $statusCode)';
  }
}
