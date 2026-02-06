import '../extensions/group_metadata_provider.dart';

/// 纯 IM 会话模型
///
/// SDK 核心数据结构，仅包含 IM 相关字段
///
/// 设计目的：
/// - 与业务数据解耦，不包含 classId、communityId 等业务字段
/// - 作为 SDK 对外暴露的标准会话模型
/// - 业务层通过 GroupMetadataProvider 扩展额外数据
///
/// 数据来源：
/// - XMPP 协议（presence、message）
/// - 本地数据库（Messages、Conversations 表）

/// 会话类型
enum ImConversationType {
  /// 单聊
  chat,

  /// 群聊（MUC）
  groupChat,

  /// 系统消息
  system,
}

/// 纯 IM 会话
///
/// 包含会话的核心 IM 数据，不含业务扩展
class ImConversation {
  /// 会话 JID（单聊为对方 bare JID，群聊为房间 bare JID）
  final String jid;

  /// 会话类型
  final ImConversationType type;

  /// 会话名称（群名/用户昵称）
  final String? name;

  /// 头像 URL
  final String? avatarUrl;

  /// 最后一条消息内容
  final String? lastMessage;

  /// 最后一条消息时间
  final DateTime? lastMessageTime;

  /// 最后一条消息发送者 JID
  final String? lastMessageSenderJid;

  /// 最后一条消息发送者昵称
  final String? lastMessageSenderName;

  /// 未读消息数
  final int unreadCount;

  /// 是否置顶
  final bool isPinned;

  /// 是否静音
  final bool isMuted;

  /// 是否已加入（群聊）
  final bool isJoined;

  /// 草稿内容
  final String? draft;

  /// 创建时间
  final DateTime? createdAt;

  /// 最后活动时间（用于排序）
  final DateTime? lastActivityTime;

  const ImConversation({
    required this.jid,
    required this.type,
    this.name,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderJid,
    this.lastMessageSenderName,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isJoined = true,
    this.draft,
    this.createdAt,
    this.lastActivityTime,
  });

  /// 是否为群聊
  bool get isGroupChat => type == ImConversationType.groupChat;

  /// 是否为单聊
  bool get isChat => type == ImConversationType.chat;

  /// 是否有未读消息
  bool get hasUnread => unreadCount > 0;

  /// 复制并修改
  ImConversation copyWith({
    String? jid,
    ImConversationType? type,
    String? name,
    String? avatarUrl,
    String? lastMessage,
    DateTime? lastMessageTime,
    String? lastMessageSenderJid,
    String? lastMessageSenderName,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? isJoined,
    String? draft,
    DateTime? createdAt,
    DateTime? lastActivityTime,
  }) {
    return ImConversation(
      jid: jid ?? this.jid,
      type: type ?? this.type,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      lastMessageSenderJid: lastMessageSenderJid ?? this.lastMessageSenderJid,
      lastMessageSenderName: lastMessageSenderName ?? this.lastMessageSenderName,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isJoined: isJoined ?? this.isJoined,
      draft: draft ?? this.draft,
      createdAt: createdAt ?? this.createdAt,
      lastActivityTime: lastActivityTime ?? this.lastActivityTime,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ImConversation &&
        other.jid == jid &&
        other.type == type &&
        other.name == name &&
        other.avatarUrl == avatarUrl &&
        other.lastMessage == lastMessage &&
        other.lastMessageTime == lastMessageTime &&
        other.unreadCount == unreadCount &&
        other.isPinned == isPinned &&
        other.isMuted == isMuted &&
        other.isJoined == isJoined &&
        other.draft == draft;
  }

  @override
  int get hashCode => Object.hash(
        jid,
        type,
        name,
        lastMessage,
        lastMessageTime,
        unreadCount,
        isPinned,
        isMuted,
        isJoined,
      );

  @override
  String toString() => 'ImConversation('
      'jid: $jid, '
      'type: $type, '
      'name: $name, '
      'unreadCount: $unreadCount, '
      'isPinned: $isPinned)';
}

/// 带业务扩展的会话
///
/// 组合 ImConversation 和 GroupMetadata，用于 UI 显示
class ExtendedConversation {
  /// 核心 IM 会话数据
  final ImConversation conversation;

  /// 业务元数据（可选）
  final GroupMetadata? metadata;

  const ExtendedConversation({
    required this.conversation,
    this.metadata,
  });

  /// 显示名称（业务名称优先，回退到 IM 名称）
  String get displayName =>
      metadata?.displayName ?? conversation.name ?? conversation.jid;

  /// 社区 ID（用于聚合）
  int? get communityId => metadata?.communityId;

  /// 是否属于社区
  bool get belongsToCommunity => communityId != null;

  /// 业务类型
  String? get businessType => metadata?.groupType;

  /// 会话 JID
  String get jid => conversation.jid;

  /// 未读数
  int get unreadCount => conversation.unreadCount;

  /// 是否置顶
  bool get isPinned => conversation.isPinned;

  /// 最后活动时间
  DateTime? get lastActivityTime => conversation.lastActivityTime;
}

