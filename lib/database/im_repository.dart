import 'dart:convert';

import 'package:drift/drift.dart';

import '../sdk/models/conversation.dart' as models;
import '../sdk/models/message.dart' as models;
import '../sdk/models/contact.dart' as models;
import '../sdk/models/media.dart' as models;
import 'app_database.dart';

/// IM 数据仓库
///
/// 封装数据库操作，提供统一的数据访问接口
class ImRepository {
  final AppDatabase _db;

  ImRepository(this._db);

  // ===== 会话操作 =====

  /// 监听会话列表
  Stream<List<models.Conversation>> watchConversations() {
    return _db.watchAllConversations().map((list) => list.map(_toModelConversation).toList());
  }

  /// 获取所有会话
  Future<List<models.Conversation>> getConversations() async {
    final list = await _db.getAllConversations();
    return list.map(_toModelConversation).toList();
  }

  /// 保存或更新会话
  Future<void> saveConversation(models.Conversation conversation) async {
    // 序列化 members 数据
    String? membersJson;
    if (conversation.members != null && conversation.members!.isNotEmpty) {
      membersJson = jsonEncode(conversation.members!.take(9).map((m) => {
        'id': m.id,
        'name': m.name,
        'avatarUrl': m.avatarUrl,
      }).toList());
    }

    await _db.upsertConversation(ConversationsCompanion(
      id: Value(conversation.id),
      name: Value(conversation.name),
      lastMessage: Value(conversation.lastMessage),
      lastMessageTime: Value(conversation.lastMessageTime),
      unreadCount: Value(conversation.unreadCount),
      isGroup: Value(conversation.isGroup),
      isPinned: Value(conversation.isPinned),
      avatar: Value(conversation.avatar),
      membersJson: Value(membersJson),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 更新群成员数据（用于群头像显示）
  Future<void> updateConversationMembers(
    String conversationId,
    List<models.ConversationMember> members,
  ) async {
    final membersJson = jsonEncode(members.take(9).map((m) => {
      'id': m.id,
      'name': m.name,
      'avatarUrl': m.avatarUrl,
    }).toList());

    await (_db.update(_db.conversations)
          ..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(
      membersJson: Value(membersJson),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 更新会话的最后消息
  Future<void> updateConversationLastMessage(
    String conversationId,
    String message,
    DateTime time, {
    bool incrementUnread = false,
  }) async {
    await _db.updateLastMessage(
      conversationId,
      message,
      time,
      incrementUnread: incrementUnread ? 1 : null,
    );
  }

  /// 清除未读数
  Future<void> clearUnread(String conversationId) async {
    await _db.clearUnread(conversationId);
  }

  /// 切换置顶
  Future<void> togglePin(String conversationId) async {
    await _db.togglePin(conversationId);
  }

  /// 删除会话
  Future<void> deleteConversation(String conversationId) async {
    await _db.deleteConversation(conversationId);
  }

  // ===== 消息操作 =====

  /// 监听消息列表
  Stream<List<models.Message>> watchMessages(String conversationId) {
    return _db.watchMessages(conversationId).map((list) => list.map(_toModelMessage).toList());
  }

  /// 获取消息列表（分页）
  Future<List<models.Message>> getMessages(String conversationId, {int limit = 50, int offset = 0}) async {
    final list = await _db.getMessages(conversationId, limit: limit, offset: offset);
    // 返回时反转顺序，因为数据库按时间降序查询
    return list.reversed.map(_toModelMessage).toList();
  }

  /// 获取指定时间之前的历史消息（用于分页加载）
  ///
  /// [conversationId] 会话 ID
  /// [beforeTimestamp] 在此时间戳之前的消息
  /// [limit] 每页数量（默认 20）
  ///
  /// 返回按时间升序排列的消息列表（最老的在前）
  Future<List<models.Message>> getMessagesBefore(
    String conversationId, {
    required DateTime beforeTimestamp,
    int limit = 20,
  }) async {
    final list = await _db.getMessagesBefore(
      conversationId,
      beforeTimestamp: beforeTimestamp,
      limit: limit,
    );
    // 数据库按时间降序返回，反转为升序（最老的在前）
    return list.reversed.map(_toModelMessage).toList();
  }

  /// 获取会话的消息总数
  Future<int> getMessageCount(String conversationId) async {
    return await _db.getMessageCount(conversationId);
  }

  /// 保存消息
  Future<void> saveMessage(models.Message message) async {
    // 构建 extra JSON（包含 replyTo 等扩展信息）
    String? extra;
    if (message.replyTo != null) {
      extra = jsonEncode({'replyTo': message.replyTo!.toJson()});
    }

    // 序列化媒体元数据
    final mediaJson = message.mediaJson;

    await _db.insertMessage(MessagesCompanion(
      id: Value(message.id),
      conversationId: Value(message.conversationId),
      senderId: Value(message.senderId),
      senderName: Value(message.senderName),
      body: Value(message.body),
      timestamp: Value(message.timestamp),
      isMe: Value(message.isMe),
      status: Value(message.status ?? 'sent'),
      type: Value(message.messageType.name),
      extra: Value(extra),
      mediaJson: Value(mediaJson),
      createdAt: Value(DateTime.now()),
    ));
  }

  /// 更新消息状态
  Future<void> updateMessageStatus(String messageId, String status) async {
    await _db.updateMessageStatus(messageId, status);
  }

  /// 搜索消息
  ///
  /// [keyword] 搜索关键词
  /// [conversationId] 可选，限定在某个会话内搜索
  /// [limit] 最大返回数量
  Future<List<models.Message>> searchMessages(
    String keyword, {
    String? conversationId,
    int limit = 100,
  }) async {
    final list = await _db.searchMessages(
      keyword,
      conversationId: conversationId,
      limit: limit,
    );
    return list.map(_toModelMessage).toList();
  }

  /// 更新消息内容（用于编辑消息）
  Future<void> updateMessageBody(String messageId, String newBody) async {
    await _db.updateMessageBody(messageId, newBody);
  }

  /// 更新消息的媒体元数据
  Future<void> updateMessageMedia(String messageId, models.MediaMetadata media) async {
    final mediaJson = jsonEncode(media.toJson());
    await _db.updateMessageMedia(messageId, mediaJson);
  }

  // ===== 草稿操作 =====

  /// 保存草稿
  Future<void> saveDraft(String conversationId, String draft) async {
    await _db.saveDraft(conversationId, draft);
  }

  /// 获取草稿
  Future<String?> getDraft(String conversationId) async {
    return await _db.getDraft(conversationId);
  }

  /// 清除草稿
  Future<void> clearDraft(String conversationId) async {
    await _db.clearDraft(conversationId);
  }

  // ===== 联系人操作 =====

  /// 监听联系人列表
  Stream<List<models.Contact>> watchContacts() {
    return _db.watchAllContacts().map((list) => list.map(_toModelContact).toList());
  }

  /// 获取所有联系人
  Future<List<models.Contact>> getContacts() async {
    final list = await _db.getAllContacts();
    return list.map(_toModelContact).toList();
  }

  /// 保存联系人
  Future<void> saveContact(models.Contact contact) async {
    await _db.upsertContact(ContactsCompanion(
      jid: Value(contact.jid),
      name: Value(contact.name),
      avatar: Value(contact.avatar),
      updatedAt: Value(DateTime.now()),
    ));
  }

  // ===== 数据转换 =====

  models.Conversation _toModelConversation(Conversation db) {
    // 解析 membersJson
    List<models.ConversationMember>? members;
    if (db.membersJson != null && db.membersJson!.isNotEmpty) {
      try {
        final list = jsonDecode(db.membersJson!) as List;
        members = list.map((m) => models.ConversationMember(
          id: m['id'] as String,
          name: m['name'] as String?,
          avatarUrl: m['avatarUrl'] as String?,
        )).toList();
      } catch (_) {
        // 解析失败，忽略
      }
    }

    return models.Conversation(
      id: db.id,
      name: db.name,
      lastMessage: db.lastMessage,
      lastMessageTime: db.lastMessageTime,
      unreadCount: db.unreadCount,
      isGroup: db.isGroup,
      isPinned: db.isPinned,
      avatar: db.avatar,
      draft: db.draft,
      members: members,
    );
  }

  models.Message _toModelMessage(Message db) {
    // 解析 extra JSON 数据
    models.ReplyInfo? replyTo;
    bool isEdited = false;

    if (db.extra != null && db.extra!.isNotEmpty) {
      // 兼容旧格式：直接是 'edited' 字符串
      if (db.extra == 'edited') {
        isEdited = true;
      } else {
        // 新格式：JSON 对象
        try {
          final extraData = jsonDecode(db.extra!) as Map<String, dynamic>;
          if (extraData['replyTo'] != null) {
            replyTo = models.ReplyInfo.fromJson(
              extraData['replyTo'] as Map<String, dynamic>,
            );
          }
          if (extraData['edited'] == true) {
            isEdited = true;
          }
        } catch (_) {
          // 解析失败，忽略
        }
      }
    }

    // 解析媒体元数据
    final media = models.Message.parseMediaJson(db.mediaJson);

    return models.Message(
      id: db.id,
      conversationId: db.conversationId,
      senderId: db.senderId,
      senderName: db.senderName,
      body: db.body,
      timestamp: db.timestamp,
      isMe: db.isMe,
      status: db.status,
      messageType: models.MessageType.values.firstWhere(
        (t) => t.name == db.type,
        orElse: () => models.MessageType.text,
      ),
      isEdited: isEdited,
      replyTo: replyTo,
      media: media,
    );
  }

  models.Contact _toModelContact(Contact db) {
    return models.Contact(
      jid: db.jid,
      name: db.name,
      avatar: db.avatar,
    );
  }
}
