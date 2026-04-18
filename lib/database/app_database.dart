import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

/// 会话表
class Conversations extends Table {
  TextColumn get id => text()(); // JID
  TextColumn get name => text()();
  TextColumn get lastMessage => text().nullable()();
  DateTimeColumn get lastMessageTime => dateTime().nullable()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  BoolColumn get isGroup => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isMuted => boolean().withDefault(const Constant(false))();
  TextColumn get avatar => text().nullable()();
  TextColumn get draft => text().nullable()(); // 草稿内容
  TextColumn get membersJson => text().nullable()(); // 群成员 JSON（用于群头像显示）
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 消息表
class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get conversationId => text().references(Conversations, #id)();
  TextColumn get senderId => text()();
  TextColumn get senderName => text()();
  TextColumn get body => text()();
  DateTimeColumn get timestamp => dateTime()();
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();
  TextColumn get status => text().withDefault(const Constant('sent'))(); // sent, delivered, read, failed
  TextColumn get type => text().withDefault(const Constant('text'))(); // text, image, file, etc.
  TextColumn get extra => text().nullable()(); // JSON for additional data (replyTo, edited, etc.)
  TextColumn get mediaJson => text().nullable()(); // JSON for media metadata (localFilePath, remoteUrl, etc.)
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

/// 联系人表
class Contacts extends Table {
  TextColumn get jid => text()();
  TextColumn get name => text()();
  TextColumn get avatar => text().nullable()();
  TextColumn get status => text().nullable()(); // online, offline, away
  DateTimeColumn get lastSeen => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {jid};
}

@DriftDatabase(tables: [Conversations, Messages, Contacts])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 5;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // 添加 draft 字段
        await m.addColumn(conversations, conversations.draft);
      }
      if (from < 3) {
        // 添加 mediaJson 字段（用于存储图片/视频/文件的本地路径等信息）
        await m.addColumn(messages, messages.mediaJson);
      }
      if (from < 4) {
        // 添加 membersJson 字段（用于存储群成员头像数据）
        await m.addColumn(conversations, conversations.membersJson);
      }
      if (from < 5) {
        // 添加 isMuted 字段（免打扰）
        await m.addColumn(conversations, conversations.isMuted);
      }
    },
  );

  // ===== 会话操作 =====

  /// 获取所有会话，按置顶和时间排序
  Future<List<Conversation>> getAllConversations() {
    return (select(conversations)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.lastMessageTime),
          ]))
        .get();
  }

  /// 监听会话列表变化
  Stream<List<Conversation>> watchAllConversations() {
    return (select(conversations)
          ..orderBy([
            (t) => OrderingTerm.desc(t.isPinned),
            (t) => OrderingTerm.desc(t.lastMessageTime),
          ]))
        .watch();
  }

  /// 插入或更新会话
  Future<void> upsertConversation(ConversationsCompanion conversation) {
    return into(conversations).insertOnConflictUpdate(conversation);
  }

  /// 更新会话的最后一条消息
  Future<void> updateLastMessage(
    String conversationId,
    String message,
    DateTime time, {
    int? incrementUnread,
  }) async {
    final existing = await (select(conversations)
          ..where((t) => t.id.equals(conversationId)))
        .getSingleOrNull();

    if (existing != null) {
      await (update(conversations)..where((t) => t.id.equals(conversationId)))
          .write(ConversationsCompanion(
        lastMessage: Value(message),
        lastMessageTime: Value(time),
        unreadCount: incrementUnread != null
            ? Value(existing.unreadCount + incrementUnread)
            : const Value.absent(),
        updatedAt: Value(DateTime.now()),
      ));
    }
  }

  /// 清除未读数
  Future<void> clearUnread(String conversationId) {
    return (update(conversations)..where((t) => t.id.equals(conversationId)))
        .write(const ConversationsCompanion(unreadCount: Value(0)));
  }

  /// 切换置顶状态
  Future<void> togglePin(String conversationId) async {
    final conversation = await (select(conversations)
          ..where((t) => t.id.equals(conversationId)))
        .getSingleOrNull();
    if (conversation != null) {
      await (update(conversations)..where((t) => t.id.equals(conversationId)))
          .write(ConversationsCompanion(isPinned: Value(!conversation.isPinned)));
    }
  }

  /// 切换免打扰状态
  Future<void> toggleMute(String conversationId) async {
    final conversation = await (select(conversations)
          ..where((t) => t.id.equals(conversationId)))
        .getSingleOrNull();
    if (conversation != null) {
      await (update(conversations)..where((t) => t.id.equals(conversationId)))
          .write(ConversationsCompanion(isMuted: Value(!conversation.isMuted)));
    }
  }

  /// 删除会话及其消息
  Future<void> deleteConversation(String conversationId) async {
    await (delete(messages)..where((t) => t.conversationId.equals(conversationId))).go();
    await (delete(conversations)..where((t) => t.id.equals(conversationId))).go();
  }

  /// 清空会话的所有消息（保留会话本身）
  Future<void> clearMessages(String conversationId) async {
    await (delete(messages)..where((t) => t.conversationId.equals(conversationId))).go();
    // 更新会话的最后一条消息为空
    await (update(conversations)..where((t) => t.id.equals(conversationId)))
        .write(const ConversationsCompanion(
      lastMessage: Value(null),
      unreadCount: Value(0),
    ));
  }

  // ===== 消息操作 =====

  /// 获取会话的消息列表
  Future<List<Message>> getMessages(String conversationId, {int limit = 50, int offset = 0}) {
    return (select(messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit, offset: offset))
        .get();
  }

  /// 获取指定消息之前的历史消息（用于分页加载）
  ///
  /// [conversationId] 会话 ID
  /// [beforeTimestamp] 在此时间戳之前的消息
  /// [limit] 每页数量
  Future<List<Message>> getMessagesBefore(
    String conversationId, {
    required DateTime beforeTimestamp,
    int limit = 20,
  }) {
    return (select(messages)
          ..where((t) =>
              t.conversationId.equals(conversationId) &
              t.timestamp.isSmallerThanValue(beforeTimestamp))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
          ..limit(limit))
        .get();
  }

  /// 获取会话的消息总数
  Future<int> getMessageCount(String conversationId) async {
    final count = countAll();
    final query = selectOnly(messages)
      ..addColumns([count])
      ..where(messages.conversationId.equals(conversationId));
    final result = await query.getSingle();
    return result.read(count) ?? 0;
  }

  /// 监听会话消息变化
  Stream<List<Message>> watchMessages(String conversationId) {
    return (select(messages)
          ..where((t) => t.conversationId.equals(conversationId))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .watch();
  }

  /// 插入消息
  Future<void> insertMessage(MessagesCompanion message) {
    return into(messages).insert(message);
  }

  /// 更新消息状态
  Future<void> updateMessageStatus(String messageId, String status) {
    return (update(messages)..where((t) => t.id.equals(messageId)))
        .write(MessagesCompanion(status: Value(status)));
  }

  /// 搜索消息
  ///
  /// [keyword] 搜索关键词
  /// [conversationId] 可选，限定在某个会话内搜索
  /// [limit] 最大返回数量
  Future<List<Message>> searchMessages(
    String keyword, {
    String? conversationId,
    int limit = 100,
  }) {
    final query = select(messages)
      ..where((t) => t.body.like('%$keyword%'))
      ..orderBy([(t) => OrderingTerm.desc(t.timestamp)])
      ..limit(limit);

    if (conversationId != null) {
      query.where((t) => t.conversationId.equals(conversationId));
    }

    return query.get();
  }

  /// 更新消息内容（用于编辑消息）
  Future<void> updateMessageBody(String messageId, String newBody) {
    return (update(messages)..where((t) => t.id.equals(messageId)))
        .write(MessagesCompanion(
      body: Value(newBody),
      extra: Value('edited'),  // 标记为已编辑
    ));
  }

  /// 更新消息的媒体元数据
  Future<void> updateMessageMedia(String messageId, String mediaJson) {
    return (update(messages)..where((t) => t.id.equals(messageId)))
        .write(MessagesCompanion(mediaJson: Value(mediaJson)));
  }

  // ===== 草稿操作 =====

  /// 保存会话草稿
  Future<void> saveDraft(String conversationId, String draft) async {
    await (update(conversations)..where((t) => t.id.equals(conversationId)))
        .write(ConversationsCompanion(
      draft: Value(draft),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// 获取会话草稿
  Future<String?> getDraft(String conversationId) async {
    final conversation = await (select(conversations)
          ..where((t) => t.id.equals(conversationId)))
        .getSingleOrNull();
    return conversation?.draft;
  }

  /// 清除会话草稿
  Future<void> clearDraft(String conversationId) async {
    await (update(conversations)..where((t) => t.id.equals(conversationId)))
        .write(const ConversationsCompanion(
      draft: Value(null),
    ));
  }

  // ===== 联系人操作 =====

  /// 获取所有联系人
  Future<List<Contact>> getAllContacts() {
    return (select(contacts)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();
  }

  /// 监听联系人列表
  Stream<List<Contact>> watchAllContacts() {
    return (select(contacts)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();
  }

  /// 插入或更新联系人
  Future<void> upsertContact(ContactsCompanion contact) {
    return into(contacts).insertOnConflictUpdate(contact);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'im_sdk.db'));
    return NativeDatabase.createInBackground(file);
  });
}
