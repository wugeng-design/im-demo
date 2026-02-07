import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart' hide Conversation, Message, Contact;
import '../database/im_repository.dart';
import '../sdk/models/conversation.dart';
import '../sdk/models/message.dart';
import '../sdk/models/contact.dart';
import '../sdk/services/impl/standalone_connection_service.dart';
import '../sdk/services/im_connection_service.dart';
import '../sdk/services/reconnect_manager.dart';

/// 数据库 Provider
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// 数据仓库 Provider
final repositoryProvider = Provider<ImRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return ImRepository(db);
});

/// IM 连接服务 Provider
final imConnectionServiceProvider = Provider<StandaloneConnectionService>((ref) {
  final service = StandaloneConnectionService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// 连接状态 Provider
final imConnectionStateProvider = StreamProvider<ConnectionStateEvent>((ref) {
  final service = ref.watch(imConnectionServiceProvider);
  return service.connectionState;
});

/// 是否已连接
final isConnectedProvider = Provider<bool>((ref) {
  final service = ref.watch(imConnectionServiceProvider);
  return service.isConnected;
});

/// 当前用户 JID
final currentJidProvider = Provider<String?>((ref) {
  final service = ref.watch(imConnectionServiceProvider);
  return service.currentJid;
});

/// 重连状态 Provider
final reconnectStateProvider = Provider<ReconnectState>((ref) {
  final service = ref.watch(imConnectionServiceProvider);
  return service.reconnectManager.state;
});

/// 是否正在重连
final isReconnectingProvider = Provider<bool>((ref) {
  final state = ref.watch(reconnectStateProvider);
  return state == ReconnectState.waiting || state == ReconnectState.reconnecting;
});

/// 会话列表 Provider（监听数据库变化）
final conversationsStreamProvider = StreamProvider<List<Conversation>>((ref) {
  final repository = ref.watch(repositoryProvider);
  return repository.watchConversations();
});

/// 会话列表 Provider（带操作方法）
final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, List<Conversation>>((ref) {
  return ConversationsNotifier(ref);
});

class ConversationsNotifier extends StateNotifier<List<Conversation>> {
  final Ref ref;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _dbSubscription;

  ConversationsNotifier(this.ref) : super([]) {
    _init();
  }

  Future<void> _init() async {
    // 从数据库加载会话列表
    await _loadFromDatabase();
    // 监听数据库变化
    _listenToDatabase();
    // 监听远程消息
    _listenToMessages();
  }

  Future<void> _loadFromDatabase() async {
    final repository = ref.read(repositoryProvider);
    state = await repository.getConversations();
  }

  void _listenToDatabase() {
    final repository = ref.read(repositoryProvider);
    _dbSubscription = repository.watchConversations().listen((conversations) {
      state = conversations;
    });
  }

  void _listenToMessages() {
    final service = ref.read(imConnectionServiceProvider);
    _messageSubscription = service.messageStream.listen((message) {
      _handleIncomingMessage(message);
    });
  }

  Future<void> _handleIncomingMessage(ReceivedMessage message) async {
    final body = message.body ?? '';

    // 检查是否是群聊邀请 (支持新旧两种格式)
    if (body.startsWith('你被邀请加入群聊')) {
      await _handleGroupInvitation(body);
      return;
    }

    // 解析 from 字段
    // 单聊: user@domain 或 user@domain/resource
    // 群聊: room@conference.domain/nickname
    final fullFrom = message.from;
    final fromBare = fullFrom.split('/').first; // 去掉 resource
    final isGroup = fromBare.contains('@conference.');

    String conversationId;
    String senderId;
    String senderName;
    bool isMe = false;

    final service = ref.read(imConnectionServiceProvider);
    final currentJid = service.currentJid;
    final myNickname = currentJid?.split('@').first ?? '';

    if (isGroup) {
      // 群聊消息: from = room@conference.domain/senderNickname
      conversationId = fromBare; // room@conference.domain
      final resource = fullFrom.contains('/') ? fullFrom.split('/').last : '';
      senderName = resource.isNotEmpty ? resource : 'Unknown';
      senderId = '$senderName@${currentJid?.split('@').last ?? 'localhost'}';

      // 检查是否是自己发的消息回显
      if (senderName == myNickname) {
        // 忽略自己发的消息回显，因为发送时已经保存了
        return;
      }
    } else {
      // 单聊消息
      conversationId = fromBare;
      senderId = fromBare;
      senderName = fromBare.split('@').first;

      // 检查是否是自己发的消息（不应该收到，但以防万一）
      if (fromBare == currentJid) {
        return;
      }
    }

    final repository = ref.read(repositoryProvider);

    // 保存消息到数据库
    final msg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      body: body,
      timestamp: message.timestamp,
      isMe: isMe,
    );
    await repository.saveMessage(msg);

    // 更新或创建会话
    final existing = state.firstWhere(
      (c) => c.id == conversationId,
      orElse: () => Conversation(
        id: conversationId,
        name: isGroup ? _extractGroupName(conversationId) : senderName,
        isGroup: isGroup,
      ),
    );

    final updated = existing.copyWith(
      lastMessage: body,
      lastMessageTime: message.timestamp,
      unreadCount: existing.unreadCount + 1,
    );

    await repository.saveConversation(updated);
  }

  Future<void> _handleGroupInvitation(String body) async {
    // 解析邀请消息，支持两种格式:
    // 新格式: 你被邀请加入群聊|群名|roomJid
    // 旧格式: 你被邀请加入群聊: roomJid
    String? roomJid;
    String? groupName;

    if (body.contains('|')) {
      // 新格式
      final parts = body.split('|');
      if (parts.length >= 3) {
        groupName = parts[1];
        roomJid = parts[2];
      }
    } else {
      // 旧格式
      final match = RegExp(r'你被邀请加入群聊:\s*(\S+)').firstMatch(body);
      if (match != null) {
        roomJid = match.group(1);
        groupName = _extractGroupName(roomJid!);
      }
    }

    if (roomJid == null) return;

    final existingIndex = state.indexWhere((c) => c.id == roomJid);

    if (existingIndex < 0) {
      final repository = ref.read(repositoryProvider);
      final conversation = Conversation(
        id: roomJid,
        name: groupName ?? '群聊',
        lastMessage: '你被邀请加入群聊',
        lastMessageTime: DateTime.now(),
        unreadCount: 1,
        isGroup: true,
      );
      await repository.saveConversation(conversation);
      await _autoJoinRoom(roomJid);
    }
  }

  String _extractGroupName(String roomJid) {
    // roomJid 格式: room_timestamp@conference.domain
    // 如果无法提取有意义的名字，返回默认值
    final local = roomJid.split('@').first;
    if (local.startsWith('room_')) {
      return '群聊';
    }
    final parts = local.split('_');
    if (parts.length > 1) {
      parts.removeLast();
      final name = parts.join('_');
      // 如果名字全是下划线或为空，返回默认值
      if (name.replaceAll('_', '').isEmpty) {
        return '群聊';
      }
      return name;
    }
    return local.isNotEmpty ? local : '群聊';
  }

  Future<void> _autoJoinRoom(String roomJid) async {
    try {
      final service = ref.read(imConnectionServiceProvider);
      final nickname = service.currentJid?.split('@').first ?? 'user';
      await service.joinRoom(roomJid, nickname);
    } catch (e) {
      // 忽略加入失败
    }
  }

  /// 添加或更新会话
  Future<void> upsertConversation(Conversation conversation) async {
    final repository = ref.read(repositoryProvider);
    await repository.saveConversation(conversation);
  }

  /// 清除未读数
  Future<void> clearUnread(String conversationId) async {
    final repository = ref.read(repositoryProvider);
    await repository.clearUnread(conversationId);
  }

  /// 置顶/取消置顶
  Future<void> togglePin(String conversationId) async {
    final repository = ref.read(repositoryProvider);
    await repository.togglePin(conversationId);
  }

  /// 删除会话
  Future<void> removeConversation(String conversationId) async {
    final repository = ref.read(repositoryProvider);
    await repository.deleteConversation(conversationId);
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _dbSubscription?.cancel();
    super.dispose();
  }
}

/// 单个会话的消息列表 Provider（监听数据库）
final messagesStreamProvider =
    StreamProvider.family<List<Message>, String>((ref, conversationId) {
  final repository = ref.watch(repositoryProvider);
  return repository.watchMessages(conversationId);
});

/// 单个会话的消息列表 Provider（带操作方法）
final messagesProvider =
    StateNotifierProvider.family<MessagesNotifier, List<Message>, String>(
        (ref, conversationId) {
  return MessagesNotifier(ref, conversationId);
});

class MessagesNotifier extends StateNotifier<List<Message>> {
  final Ref ref;
  final String conversationId;
  StreamSubscription? _messageSubscription;
  StreamSubscription? _dbSubscription;

  /// 每次加载的消息数量
  static const int _pageSize = 20;

  /// 是否还有更多本地历史消息
  bool _hasMoreHistory = true;

  /// 是否正在加载历史消息
  bool _isLoadingHistory = false;

  /// 是否正在刷新
  bool _isRefreshing = false;

  MessagesNotifier(this.ref, this.conversationId) : super([]) {
    _init();
  }

  /// 是否还有更多历史消息
  bool get hasMoreHistory => _hasMoreHistory;

  /// 是否正在加载历史消息
  bool get isLoadingHistory => _isLoadingHistory;

  /// 是否正在刷新
  bool get isRefreshing => _isRefreshing;

  Future<void> _init() async {
    // 从数据库加载历史消息
    await _loadFromDatabase();
    // 监听数据库变化
    _listenToDatabase();
    // 监听远程消息
    _listenToMessages();
  }

  Future<void> _loadFromDatabase() async {
    final repository = ref.read(repositoryProvider);
    state = await repository.getMessages(conversationId, limit: _pageSize);

    // 检查是否有更多历史消息
    final totalCount = await repository.getMessageCount(conversationId);
    _hasMoreHistory = state.length < totalCount;
  }

  void _listenToDatabase() {
    final repository = ref.read(repositoryProvider);
    _dbSubscription = repository.watchMessages(conversationId).listen((messages) {
      // 保持当前分页状态，只更新已加载的部分
      if (state.isEmpty) {
        state = messages.take(_pageSize).toList();
      } else {
        // 找到当前最旧消息的时间
        final oldestTimestamp = state.first.timestamp;
        // 保留已加载的历史消息 + 新消息
        final newMessages = messages.where(
          (m) => m.timestamp.isAfter(oldestTimestamp) ||
                 state.any((s) => s.id == m.id)
        ).toList();
        if (newMessages.isNotEmpty) {
          state = newMessages;
        }
      }
    });
  }

  void _listenToMessages() {
    final service = ref.read(imConnectionServiceProvider);
    _messageSubscription = service.messageStream.listen((message) {
      final fromJid = message.from.split('/').first;
      if (fromJid == conversationId) {
        // 消息已在 ConversationsNotifier 中保存到数据库
        // 这里只需要等待数据库更新即可
      }
    });
  }

  /// 加载更多历史消息（滚动到顶部时调用）
  Future<void> loadMoreHistory() async {
    if (!_hasMoreHistory || _isLoadingHistory || state.isEmpty) {
      return;
    }

    _isLoadingHistory = true;

    try {
      final repository = ref.read(repositoryProvider);

      // 获取当前最旧消息的时间戳
      final oldestMessage = state.first;
      final olderMessages = await repository.getMessagesBefore(
        conversationId,
        beforeTimestamp: oldestMessage.timestamp,
        limit: _pageSize,
      );

      if (olderMessages.isEmpty) {
        _hasMoreHistory = false;
        return;
      }

      // 如果返回数量少于请求数量，说明没有更多了
      if (olderMessages.length < _pageSize) {
        _hasMoreHistory = false;
      }

      // 将历史消息插入到列表开头
      state = [...olderMessages, ...state];
    } catch (e) {
      // 加载失败时保持原状态
    } finally {
      _isLoadingHistory = false;
    }
  }

  /// 从服务器刷新消息（下拉刷新时调用）
  ///
  /// 目前演示版本只从本地数据库重新加载
  /// 实际项目中应调用 MAM 同步
  Future<void> refreshFromServer() async {
    if (_isRefreshing) return;

    _isRefreshing = true;

    try {
      // TODO: 实际项目中这里应该调用 MAM 同步
      // 目前只从数据库重新加载
      final repository = ref.read(repositoryProvider);
      final messages = await repository.getMessages(conversationId, limit: _pageSize);

      final totalCount = await repository.getMessageCount(conversationId);
      _hasMoreHistory = messages.length < totalCount;

      state = messages;
    } finally {
      _isRefreshing = false;
    }
  }

  void addMessage(Message message) {
    state = [...state, message];
  }

  Future<void> sendMessage(String body) async {
    final service = ref.read(imConnectionServiceProvider);
    final repository = ref.read(repositoryProvider);
    final currentJid = service.currentJid;

    if (currentJid == null) return;

    final message = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
      senderId: currentJid,
      senderName: currentJid.split('@').first,
      body: body,
      timestamp: DateTime.now(),
      isMe: true,
      status: 'sending',
    );

    // 保存到数据库（会触发 UI 更新）
    await repository.saveMessage(message);

    // 发送到服务器
    try {
      final isGroup = conversationId.contains('@conference.');
      await service.sendMessage(conversationId, body, isGroupChat: isGroup);

      // 更新消息状态为已发送
      await repository.updateMessageStatus(message.id, 'sent');

      // 更新会话列表 (保留原有的会话名称)
      final existingConversation = ref.read(conversationsProvider).firstWhere(
        (c) => c.id == conversationId,
        orElse: () => Conversation(
          id: conversationId,
          name: isGroup ? '群聊' : conversationId.split('@').first,
          isGroup: isGroup,
        ),
      );
      await ref.read(conversationsProvider.notifier).upsertConversation(
            existingConversation.copyWith(
              lastMessage: body,
              lastMessageTime: DateTime.now(),
            ),
          );
    } catch (e) {
      // 更新消息状态为失败
      await repository.updateMessageStatus(message.id, 'failed');
    }
  }

  /// 重试发送失败的消息
  Future<void> retryMessage(Message message) async {
    final service = ref.read(imConnectionServiceProvider);
    final repository = ref.read(repositoryProvider);

    // 更新状态为发送中
    await repository.updateMessageStatus(message.id, 'sending');

    try {
      final isGroup = conversationId.contains('@conference.');
      await service.sendMessage(conversationId, message.body, isGroupChat: isGroup);

      // 更新状态为已发送
      await repository.updateMessageStatus(message.id, 'sent');
    } catch (e) {
      // 更新状态为失败
      await repository.updateMessageStatus(message.id, 'failed');
    }
  }

  /// 删除消息（本地删除）
  Future<void> deleteMessage(String messageId) async {
    final db = ref.read(databaseProvider);

    // 从数据库删除消息
    await (db.delete(db.messages)..where((t) => t.id.equals(messageId))).go();

    // 从状态中移除
    state = state.where((m) => m.id != messageId).toList();
  }

  /// 撤回消息
  ///
  /// 目前只是本地删除并添加系统消息
  /// 实际项目中需要调用 XMPP 撤回协议
  Future<void> recallMessage(String messageId) async {
    final repository = ref.read(repositoryProvider);
    final db = ref.read(databaseProvider);

    // 找到要撤回的消息
    final message = state.firstWhere(
      (m) => m.id == messageId,
      orElse: () => throw StateError('Message not found'),
    );

    // 从数据库删除原消息
    await (db.delete(db.messages)..where((t) => t.id.equals(messageId))).go();

    // 创建撤回提示消息
    final recallNotice = Message(
      id: '${messageId}_recall',
      conversationId: conversationId,
      senderId: message.senderId,
      senderName: message.senderName,
      body: '你撤回了一条消息',
      timestamp: message.timestamp,
      isMe: message.isMe,
      messageType: MessageType.system,
    );

    await repository.saveMessage(recallNotice);

    // TODO: 实际项目中这里应该发送 XMPP 撤回请求
  }

  /// 编辑消息
  ///
  /// 目前只是本地更新消息内容
  /// 实际项目中需要调用 XMPP 编辑协议 (XEP-0308)
  Future<void> editMessage(String messageId, String newBody) async {
    final db = ref.read(databaseProvider);

    // 更新数据库中的消息内容
    await (db.update(db.messages)..where((t) => t.id.equals(messageId)))
        .write(MessagesCompanion(
      body: Value(newBody),
    ));

    // 更新状态中的消息
    state = state.map((m) {
      if (m.id == messageId) {
        return m.copyWith(body: newBody);
      }
      return m;
    }).toList();

    // TODO: 实际项目中这里应该发送 XMPP 编辑请求 (XEP-0308)
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _dbSubscription?.cancel();
    super.dispose();
  }
}

/// 联系人列表 Provider (模拟数据)
final contactsProvider = Provider<List<Contact>>((ref) {
  final currentJid = ref.watch(currentJidProvider);
  final domain = currentJid?.split('@').last ?? 'localhost';

  // 返回一些模拟联系人
  return [
    Contact(jid: 'admin@$domain', name: 'Admin'),
    Contact(jid: 'user1@$domain', name: 'User 1'),
    Contact(jid: 'user2@$domain', name: 'User 2'),
    Contact(jid: 'user3@$domain', name: 'User 3'),
    Contact(jid: 'test@$domain', name: 'Test User'),
  ].where((c) => c.jid != currentJid).toList();
});
