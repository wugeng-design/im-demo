/// 群成员头像信息（用于群头像显示）
class ConversationMember {
  final String id;
  final String? name;
  final String? avatarUrl;

  const ConversationMember({
    required this.id,
    this.name,
    this.avatarUrl,
  });
}

/// 会话模型
class Conversation {
  final String id; // JID
  final String name;
  final String? avatar;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isGroup;
  final String? draft;
  /// 群成员列表（用于群头像显示，最多9个）
  final List<ConversationMember>? members;

  const Conversation({
    required this.id,
    required this.name,
    this.avatar,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.isGroup = false,
    this.draft,
    this.members,
  });

  /// 是否有草稿
  bool get hasDraft => draft != null && draft!.isNotEmpty;

  Conversation copyWith({
    String? id,
    String? name,
    String? avatar,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? isGroup,
    String? draft,
    List<ConversationMember>? members,
  }) {
    return Conversation(
      id: id ?? this.id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      isGroup: isGroup ?? this.isGroup,
      draft: draft ?? this.draft,
      members: members ?? this.members,
    );
  }
}
