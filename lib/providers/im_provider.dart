import 'dart:async';
import 'dart:io';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart' hide Conversation, Message, Contact;
import '../database/im_repository.dart';
import '../sdk/models/conversation.dart';
import '../sdk/models/message.dart';
import '../sdk/models/contact.dart';
import '../sdk/models/media.dart';
import '../sdk/services/impl/standalone_connection_service.dart';
import '../sdk/services/impl/xep0363_upload_service.dart';
import '../sdk/services/im_connection_service.dart';
import '../sdk/services/media_upload_service.dart';
import '../sdk/services/reconnect_manager.dart';
import '../sdk/services/typing_indicator_service.dart';

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

/// 媒体上传服务 Provider
///
/// 使用 XEP-0363 HTTP File Upload 协议
/// 通过 XMPP IQ 请求上传 slot，然后 PUT 到服务器
final mediaUploadServiceProvider = Provider<MediaUploadService>((ref) {
  final connectionService = ref.watch(imConnectionServiceProvider);
  final config = connectionService.savedConfig;
  final whixp = connectionService.whixp;

  // 需要 whixp 实例和 domain 才能创建上传服务
  if (whixp == null) {
    // 返回一个空实现，等待连接建立
    return _PlaceholderUploadService();
  }

  final domain = config?.domain ?? 'localhost';
  final service = Xep0363UploadService(domain: domain, whixp: whixp);
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

/// 输入状态指示器服务 Provider
final typingIndicatorServiceProvider = Provider<TypingIndicatorService>((ref) {
  final service = TypingIndicatorService();
  // 设置当前用户 JID
  final connectionService = ref.watch(imConnectionServiceProvider);
  service.currentUserJid = connectionService.currentJid;
  ref.onDispose(() => service.dispose());
  return service;
});

/// 指定会话的输入状态 Provider
final typingStateProvider = StreamProvider.family<TypingStateEvent?, String>((ref, conversationId) {
  final service = ref.watch(typingIndicatorServiceProvider);
  return service.typingStateStream.where((e) => e.conversationId == conversationId);
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

    // 解析媒体消息格式: [TYPE:filename]url
    final parsedMedia = _parseMediaMessage(body);
    final messageType = parsedMedia?.type ?? MessageType.text;
    final displayBody = parsedMedia?.url ?? body;

    // 保存消息到数据库
    final msg = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      body: displayBody,
      timestamp: message.timestamp,
      isMe: isMe,
      messageType: messageType,
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

    // 会话列表显示友好文本
    final lastMessageText = switch (messageType) {
      MessageType.image => '[图片]',
      MessageType.video => '[视频]',
      MessageType.file => '[文件]',
      _ => body,
    };

    final updated = existing.copyWith(
      lastMessage: lastMessageText,
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

  /// 解析媒体消息格式: [TYPE:filename]url
  ///
  /// 返回解析结果，如果不是媒体消息则返回 null
  _ParsedMediaMessage? _parseMediaMessage(String body) {
    // 匹配格式: [IMG:filename]url 或 [VIDEO:filename]url 或 [FILE:filename]url
    final regex = RegExp(r'^\[(IMG|VIDEO|FILE):([^\]]+)\](.+)$');
    final match = regex.firstMatch(body);

    if (match == null) return null;

    final typeTag = match.group(1)!;
    final fileName = match.group(2)!;
    final url = match.group(3)!;

    final type = switch (typeTag) {
      'IMG' => MessageType.image,
      'VIDEO' => MessageType.video,
      'FILE' => MessageType.file,
      _ => MessageType.text,
    };

    return _ParsedMediaMessage(type: type, fileName: fileName, url: url);
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

  Future<void> sendMessage(String body, {ReplyInfo? replyTo}) async {
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
      replyTo: replyTo,
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

/// 转发消息结果
class ForwardMessageResult {
  final bool success;
  final String? messageId;
  final String? error;

  const ForwardMessageResult._({
    required this.success,
    this.messageId,
    this.error,
  });

  factory ForwardMessageResult.success(String messageId) =>
      ForwardMessageResult._(success: true, messageId: messageId);

  factory ForwardMessageResult.failure(String error) =>
      ForwardMessageResult._(success: false, error: error);
}

/// 消息转发服务
///
/// 将消息转发到其他会话
class MessageForwarder {
  final Ref ref;

  MessageForwarder(this.ref);

  /// 转发消息
  ///
  /// [message] 要转发的消息
  /// [targetConversationId] 目标会话 ID
  /// [isGroupChat] 是否群聊
  Future<ForwardMessageResult> forwardMessage({
    required Message message,
    required String targetConversationId,
    required bool isGroupChat,
  }) async {
    final service = ref.read(imConnectionServiceProvider);
    final repository = ref.read(repositoryProvider);
    final currentJid = service.currentJid;

    if (currentJid == null) {
      return ForwardMessageResult.failure('未连接到服务器');
    }

    final newMessageId = DateTime.now().millisecondsSinceEpoch.toString();
    final now = DateTime.now();

    // 构建转发消息体
    String forwardBody = message.body;
    MessageType messageType = message.messageType;
    MediaMetadata? media;

    // 处理媒体消息
    if (message.messageType == MessageType.image ||
        message.messageType == MessageType.video ||
        message.messageType == MessageType.file) {
      // 复制媒体信息（使用远程 URL）
      if (message.media != null) {
        media = MediaMetadata(
          type: message.media!.type,
          remoteUrl: message.media!.remoteUrl,
          thumbnailUrl: message.media!.thumbnailUrl,
          fileName: message.media!.fileName,
          mimeType: message.media!.mimeType,
          fileSize: message.media!.fileSize,
          width: message.media!.width,
          height: message.media!.height,
          duration: message.media!.duration,
        );
      }
    }

    // 创建新消息
    final forwardedMessage = Message(
      id: newMessageId,
      conversationId: targetConversationId,
      senderId: currentJid,
      senderName: currentJid.split('@').first,
      body: forwardBody,
      timestamp: now,
      isMe: true,
      status: 'sending',
      messageType: messageType,
      media: media,
    );

    try {
      // 保存到数据库
      await repository.saveMessage(forwardedMessage);

      // 发送到服务器
      await service.sendMessage(
        targetConversationId,
        forwardBody,
        isGroupChat: isGroupChat,
      );

      // 更新消息状态
      await repository.updateMessageStatus(newMessageId, 'sent');

      // 更新目标会话的最后消息
      final existingConversation = ref.read(conversationsProvider).firstWhere(
        (c) => c.id == targetConversationId,
        orElse: () => Conversation(
          id: targetConversationId,
          name: isGroupChat ? '群聊' : targetConversationId.split('@').first,
          isGroup: isGroupChat,
        ),
      );

      await ref.read(conversationsProvider.notifier).upsertConversation(
        existingConversation.copyWith(
          lastMessage: _getPreviewText(forwardBody, messageType),
          lastMessageTime: now,
        ),
      );

      return ForwardMessageResult.success(newMessageId);
    } catch (e) {
      await repository.updateMessageStatus(newMessageId, 'failed');
      return ForwardMessageResult.failure(e.toString());
    }
  }

  /// 获取消息预览文本
  String _getPreviewText(String body, MessageType type) {
    switch (type) {
      case MessageType.image:
        return '[图片]';
      case MessageType.video:
        return '[视频]';
      case MessageType.file:
        return '[文件]';
      default:
        return body.length > 50 ? '${body.substring(0, 50)}...' : body;
    }
  }
}

/// 消息转发 Provider
final messageForwarderProvider = Provider<MessageForwarder>((ref) {
  return MessageForwarder(ref);
});

/// 联系人列表 Provider (从服务器获取)
final contactsProvider = FutureProvider<List<Contact>>((ref) async {
  final service = ref.watch(imConnectionServiceProvider);
  final isConnected = ref.watch(isConnectedProvider);

  if (!isConnected) {
    return [];
  }

  try {
    final userJids = await service.getRegisteredUsers();
    return userJids.map((jid) {
      final username = jid.split('@').first;
      // 将用户名首字母大写作为显示名
      final displayName = username[0].toUpperCase() + username.substring(1);
      return Contact(jid: jid, name: displayName);
    }).toList();
  } catch (e) {
    print('[Contacts] 获取联系人失败: $e');
    return [];
  }
});

/// 解析后的媒体消息
class _ParsedMediaMessage {
  final MessageType type;
  final String fileName;
  final String url;

  _ParsedMediaMessage({
    required this.type,
    required this.fileName,
    required this.url,
  });
}

/// 上传进度 Provider
///
/// 跟踪每个消息的上传进度 (0.0 - 1.0)
final uploadProgressProvider = StateNotifierProvider<UploadProgressNotifier, Map<String, double>>((ref) {
  return UploadProgressNotifier();
});

class UploadProgressNotifier extends StateNotifier<Map<String, double>> {
  UploadProgressNotifier() : super({});

  /// 更新上传进度
  void updateProgress(String messageId, double progress) {
    state = {...state, messageId: progress};
  }

  /// 移除上传进度（上传完成或失败后调用）
  void removeProgress(String messageId) {
    final newState = Map<String, double>.from(state);
    newState.remove(messageId);
    state = newState;
  }

  /// 获取指定消息的上传进度
  double? getProgress(String messageId) => state[messageId];
}

/// 占位上传服务（未连接时使用）
class _PlaceholderUploadService implements MediaUploadService {
  @override
  Future<MediaUploadResult> uploadImage({
    required String messageId,
    required File file,
    UploadProgressCallback? onProgress,
  }) async {
    return MediaUploadResult.failure('未连接到服务器');
  }

  @override
  Future<MediaUploadResult> uploadVideo({
    required String messageId,
    required File file,
    UploadProgressCallback? onProgress,
  }) async {
    return MediaUploadResult.failure('未连接到服务器');
  }

  @override
  Future<MediaUploadResult> uploadFile({
    required String messageId,
    required File file,
    required String mimeType,
    UploadProgressCallback? onProgress,
  }) async {
    return MediaUploadResult.failure('未连接到服务器');
  }

  @override
  bool cancelUpload(String messageId) => false;

  @override
  Future<MediaUploadResult> retryUpload(String messageId) async {
    return MediaUploadResult.failure('未连接到服务器');
  }

  @override
  UploadTask? getUploadTask(String messageId) => null;

  @override
  Stream<UploadTask> get uploadTaskStream => const Stream.empty();

  void dispose() {}
}
