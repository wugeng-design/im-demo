/// 成员同步提供者接口
///
/// SDK 扩展点：允许业务层提供群成员的同步数据源
///
/// 设计目的：
/// - 将业务 API 的成员数据获取与 IM SDK 解耦
/// - 支持不同业务场景的成员同步逻辑（班级成员、社区成员等）
/// - SDK 只负责 XMPP presence 和本地存储，业务数据由业务层提供
///
/// 使用示例：
/// ```dart
/// class EdxMemberSyncProvider implements MemberSyncProvider {
///   final EdxApiClient _apiClient;
///
///   @override
///   Future<List<MemberInfo>> syncGroupMembers(String roomBareJid) async {
///     final classId = await _getClassId(roomBareJid);
///     final students = await _apiClient.getClassMembers(classId);
///     return students.map((s) => MemberInfo(
///       memberJid: s.xmppJid,
///       displayName: s.realName,
///       avatarUrl: s.avatar,
///       role: s.isTeacher ? MemberRole.admin : MemberRole.member,
///     )).toList();
///   }
/// }
/// ```

/// 成员角色
enum MemberRole {
  /// 群主
  owner,

  /// 管理员
  admin,

  /// 普通成员
  member,

  /// 访客（只读）
  visitor,
}

/// 成员信息
///
/// 业务层提供的成员数据结构
class MemberInfo {
  /// 成员 XMPP JID（bare JID）
  final String memberJid;

  /// 业务系统用户 ID
  final String? userId;

  /// 显示名称（业务层提供，如真实姓名）
  final String? displayName;

  /// 头像 URL
  final String? avatarUrl;

  /// 成员角色
  final MemberRole role;

  /// 额外业务数据
  final Map<String, dynamic> extra;

  const MemberInfo({
    required this.memberJid,
    this.userId,
    this.displayName,
    this.avatarUrl,
    this.role = MemberRole.member,
    Map<String, dynamic>? extra,
  }) : extra = extra ?? const {};

  @override
  String toString() => 'MemberInfo('
      'memberJid: $memberJid, '
      'displayName: $displayName, '
      'role: $role)';
}

/// 成员同步结果
class MemberSyncResult {
  /// 成功同步的成员列表
  final List<MemberInfo> members;

  /// 是否完整同步（false 表示增量）
  final bool isFullSync;

  /// 同步时间戳
  final DateTime syncTime;

  /// 错误信息（部分失败时）
  final String? errorMessage;

  const MemberSyncResult({
    required this.members,
    this.isFullSync = true,
    required this.syncTime,
    this.errorMessage,
  });

  /// 空结果
  static final empty = MemberSyncResult(
    members: const [],
    syncTime: DateTime.now(),
  );

  bool get hasError => errorMessage != null;
}

/// 成员同步提供者接口
///
/// 业务层实现此接口，为 IM SDK 提供群成员的业务数据
abstract class MemberSyncProvider {
  /// 同步群组成员
  ///
  /// [roomBareJid] 群组 JID
  /// 返回成员信息列表，用于与本地数据库合并
  Future<MemberSyncResult> syncGroupMembers(String roomBareJid);

  /// 获取单个成员信息
  ///
  /// [roomBareJid] 群组 JID
  /// [memberJid] 成员 JID
  Future<MemberInfo?> getMemberInfo(String roomBareJid, String memberJid);

  /// 监听成员变化事件
  ///
  /// 当业务层检测到成员变化（如新学生加入班级）时，通过此流通知 SDK
  Stream<MemberChangeEvent> get memberChanges;

  /// 是否支持指定群组的成员同步
  ///
  /// 返回 false 时，SDK 使用 XMPP MUC 协议获取成员
  bool supportsGroup(String roomBareJid);
}

/// 成员变化事件类型
enum MemberChangeType {
  /// 成员加入
  joined,

  /// 成员离开
  left,

  /// 成员信息更新
  updated,

  /// 成员角色变更
  roleChanged,
}

/// 成员变化事件
class MemberChangeEvent {
  /// 群组 JID
  final String roomBareJid;

  /// 变化类型
  final MemberChangeType type;

  /// 相关成员
  final MemberInfo member;

  const MemberChangeEvent({
    required this.roomBareJid,
    required this.type,
    required this.member,
  });
}

/// 默认空实现
///
/// 当业务层未注册 Provider 时使用，SDK 回退到纯 XMPP 模式
class NoOpMemberSyncProvider implements MemberSyncProvider {
  const NoOpMemberSyncProvider();

  @override
  Future<MemberSyncResult> syncGroupMembers(String roomBareJid) async =>
      MemberSyncResult.empty;

  @override
  Future<MemberInfo?> getMemberInfo(
    String roomBareJid,
    String memberJid,
  ) async =>
      null;

  @override
  Stream<MemberChangeEvent> get memberChanges => const Stream.empty();

  @override
  bool supportsGroup(String roomBareJid) => false;
}
