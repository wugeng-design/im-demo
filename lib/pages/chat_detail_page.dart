import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/im_provider.dart';
import '../sdk/models/message.dart';
import '../sdk/models/media.dart';
import '../theme/im_design_tokens.dart';
import '../widgets/message_bubbles/message_bubbles.dart';
import '../widgets/input/input.dart';
import 'group_detail_page.dart';

/// 聊天详情页面
class ChatDetailPage extends ConsumerStatefulWidget {
  final String conversationId;
  final String conversationName;
  final bool isGroup;

  const ChatDetailPage({
    super.key,
    required this.conversationId,
    required this.conversationName,
    this.isGroup = false,
  });

  @override
  ConsumerState<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends ConsumerState<ChatDetailPage> {
  final _scrollController = ScrollController();
  final _inputKey = GlobalKey<MessageInputAreaState>();

  /// 触发加载更多的滚动阈值（距离顶部多少像素）
  static const double _loadMoreThreshold = 100.0;

  /// 正在编辑的消息（null 表示非编辑模式）
  Message? _editingMessage;

  /// 正在回复的消息
  Message? _replyingMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 滚动监听：到达顶部时加载更多历史
  void _onScroll() {
    if (_scrollController.position.pixels <= _loadMoreThreshold) {
      _loadMoreHistory();
    }
  }

  /// 加载更多历史消息
  Future<void> _loadMoreHistory() async {
    final notifier = ref.read(messagesProvider(widget.conversationId).notifier);
    if (!notifier.hasMoreHistory || notifier.isLoadingHistory) {
      return;
    }
    await notifier.loadMoreHistory();
  }

  /// 下拉刷新
  Future<void> _onRefresh() async {
    await ref
        .read(messagesProvider(widget.conversationId).notifier)
        .refreshFromServer();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendTextMessage(String text) async {
    await ref
        .read(messagesProvider(widget.conversationId).notifier)
        .sendMessage(text);
    _scrollToBottom();
  }

  void _onImageSelected(File file) {
    _sendMediaMessage(file, MediaType.image);
  }

  void _onMultipleImagesSelected(List<File> files) {
    for (final file in files) {
      _sendMediaMessage(file, MediaType.image);
    }
  }

  void _onVideoSelected(File file) {
    _sendMediaMessage(file, MediaType.video);
  }

  void _onFileSelected(File file) {
    _sendMediaMessage(file, MediaType.file);
  }

  void _sendMediaMessage(File file, MediaType type) {
    // TODO: 实现媒体消息发送
    // 1. 创建本地消息（乐观更新）
    // 2. 上传媒体文件
    // 3. 发送 XMPP 消息
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('即将发送: ${file.path.split('/').last}')),
    );
  }

  // ========== 消息操作 ==========

  /// 显示消息长按菜单
  Future<void> _showMessageMenu(Message message, Offset position) async {
    final action = await MessageLongPressMenu.show(
      context: context,
      message: message,
      position: position,
    );

    if (action == null || !mounted) return;

    switch (action) {
      case MessageMenuAction.copy:
        _copyMessage(message);
      case MessageMenuAction.retry:
        _retryMessage(message);
      case MessageMenuAction.delete:
        _deleteMessage(message);
      case MessageMenuAction.recall:
        _recallMessage(message);
      case MessageMenuAction.edit:
        _startEditMessage(message);
      case MessageMenuAction.reply:
        _startReplyMessage(message);
      case MessageMenuAction.forward:
        _forwardMessage(message);
    }
  }

  /// 复制消息
  void _copyMessage(Message message) {
    Clipboard.setData(ClipboardData(text: message.body));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// 重试发送失败的消息
  Future<void> _retryMessage(Message message) async {
    // TODO: 实现重试逻辑
    // 1. 更新消息状态为 sending
    // 2. 重新发送消息
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在重试发送...')),
    );

    // 模拟重试
    await ref
        .read(messagesProvider(widget.conversationId).notifier)
        .retryMessage(message);
  }

  /// 删除消息（本地删除）
  Future<void> _deleteMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除消息'),
        content: const Text('确定要删除这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await ref
          .read(messagesProvider(widget.conversationId).notifier)
          .deleteMessage(message.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('消息已删除'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// 撤回消息
  Future<void> _recallMessage(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤回消息'),
        content: const Text('确定要撤回这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('撤回'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      // TODO: 实现撤回逻辑（需要 XMPP 支持）
      await ref
          .read(messagesProvider(widget.conversationId).notifier)
          .recallMessage(message.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('消息已撤回'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  }

  /// 开始编辑消息
  void _startEditMessage(Message message) {
    setState(() {
      _editingMessage = message;
      _replyingMessage = null;
    });
    // 设置输入框内容为消息文本
    _inputKey.currentState?.setText(message.body);
    _inputKey.currentState?.focus();
  }

  /// 取消编辑
  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
    });
    _inputKey.currentState?.clear();
  }

  /// 提交编辑
  Future<void> _submitEdit(String newText) async {
    if (_editingMessage == null) return;

    final messageId = _editingMessage!.id;
    setState(() {
      _editingMessage = null;
    });

    // TODO: 实现编辑逻辑（需要 XMPP 支持）
    await ref
        .read(messagesProvider(widget.conversationId).notifier)
        .editMessage(messageId, newText);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('消息已编辑'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// 开始回复消息
  void _startReplyMessage(Message message) {
    setState(() {
      _replyingMessage = message;
      _editingMessage = null;
    });
    _inputKey.currentState?.focus();
  }

  /// 取消回复
  void _cancelReply() {
    setState(() {
      _replyingMessage = null;
    });
  }

  /// 转发消息
  void _forwardMessage(Message message) {
    // TODO: 实现转发逻辑（显示会话选择器）
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('转发功能开发中')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final isConnected = ref.watch(isConnectedProvider);
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.conversationName),
            if (widget.isGroup)
              Text(
                '群聊',
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
          ],
        ),
        backgroundColor: colors.surface,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showChatSettings(context),
          ),
        ],
      ),
      backgroundColor: colors.background,
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState(colors)
                : _buildMessageList(messages, colors),
          ),
          // 编辑/回复指示栏
          if (_editingMessage != null || _replyingMessage != null)
            _buildEditReplyBar(colors),
          // 输入区域
          if (isConnected)
            MessageInputArea(
              key: _inputKey,
              onSend: _editingMessage != null
                  ? _submitEdit
                  : _sendTextMessage,
              onImageSelected: _onImageSelected,
              onMultipleImagesSelected: _onMultipleImagesSelected,
              onVideoSelected: _onVideoSelected,
              onFileSelected: _onFileSelected,
            )
          else
            _buildDisconnectedBar(colors),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ImColorScheme colors) {
    // 空状态也支持下拉刷新
    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline, size: 48, color: colors.textTertiary),
                    const SizedBox(height: 16),
                    Text(
                      '暂无消息',
                      style: TextStyle(color: colors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '发送消息开始聊天吧',
                      style: TextStyle(color: colors.textTertiary, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '下拉刷新',
                      style: TextStyle(color: colors.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMessageList(List<Message> messages, ImColorScheme colors) {
    final notifier = ref.watch(messagesProvider(widget.conversationId).notifier);
    final hasMore = notifier.hasMoreHistory;
    final isLoading = notifier.isLoadingHistory;

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        // 增加一项用于显示加载更多指示器
        itemCount: messages.length + (hasMore || isLoading ? 1 : 0),
        itemBuilder: (context, index) {
          // 第一项：加载更多指示器
          if (hasMore || isLoading) {
            if (index == 0) {
              return _buildLoadMoreIndicator(colors, isLoading, hasMore);
            }
            // 其他项索引减一
            index = index - 1;
          }

          final message = messages[index];
          final showTime = index == 0 ||
              messages[index]
                      .timestamp
                      .difference(messages[index - 1].timestamp)
                      .inMinutes >
                  5;

          return Column(
            children: [
              if (showTime) _buildTimeHeader(message.timestamp, colors),
              _buildMessageBubble(message, colors),
            ],
          );
        },
      ),
    );
  }

  /// 构建加载更多指示器
  Widget _buildLoadMoreIndicator(ImColorScheme colors, bool isLoading, bool hasMore) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: isLoading
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors.textTertiary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '加载中...',
                  style: TextStyle(color: colors.textTertiary, fontSize: 12),
                ),
              ],
            )
          : hasMore
              ? GestureDetector(
                  onTap: _loadMoreHistory,
                  child: Text(
                    '上滑加载更多历史消息',
                    style: TextStyle(color: colors.textTertiary, fontSize: 12),
                  ),
                )
              : const SizedBox.shrink(),
    );
  }

  Widget _buildTimeHeader(DateTime time, ImColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        _formatMessageTime(time),
        style: TextStyle(color: colors.textTertiary, fontSize: 12),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, ImColorScheme colors) {
    // 解析消息状态
    MessageDisplayStatus? status;
    switch (message.status) {
      case 'sending':
        status = MessageDisplayStatus.sending;
        break;
      case 'sent':
        status = MessageDisplayStatus.sent;
        break;
      case 'delivered':
        status = MessageDisplayStatus.delivered;
        break;
      case 'read':
        status = MessageDisplayStatus.read;
        break;
      case 'failed':
        status = MessageDisplayStatus.failed;
        break;
    }

    // 是否显示头像（始终显示）
    const showAvatar = true;

    // 长按菜单回调（使用 Builder 获取正确的位置）
    void onLongPress(TapDownDetails details) {
      _showMessageMenu(message, details.globalPosition);
    }

    // 重试回调
    void onRetry() {
      _retryMessage(message);
    }

    // 根据消息类型选择气泡
    switch (message.messageType) {
      case MessageType.image:
        return GestureDetector(
          onLongPressStart: (details) => onLongPress(TapDownDetails(globalPosition: details.globalPosition)),
          child: ImageMessageBubble(
            isSentByMe: message.isMe,
            localFilePath: message.media?.localFilePath,
            imageUrl: message.media?.remoteUrl,
            width: message.media?.width?.toDouble(),
            height: message.media?.height?.toDouble(),
            status: status,
            senderId: message.senderId,
            senderName: message.senderName,
            senderAvatar: message.senderAvatar,
            showAvatar: showAvatar,
            onTap: () => _previewImage(message),
            onRetry: onRetry,
          ),
        );

      case MessageType.video:
        return GestureDetector(
          onLongPressStart: (details) => onLongPress(TapDownDetails(globalPosition: details.globalPosition)),
          child: VideoMessageBubble(
            isSentByMe: message.isMe,
            thumbnailPath: message.media?.thumbnailUrl,
            thumbnailUrl: message.media?.thumbnailUrl,
            duration: message.media?.duration,
            width: message.media?.width?.toDouble(),
            height: message.media?.height?.toDouble(),
            status: status,
            senderId: message.senderId,
            senderName: message.senderName,
            senderAvatar: message.senderAvatar,
            showAvatar: showAvatar,
            onTap: () => _playVideo(message),
            onRetry: onRetry,
          ),
        );

      case MessageType.file:
        return GestureDetector(
          onLongPressStart: (details) => onLongPress(TapDownDetails(globalPosition: details.globalPosition)),
          child: FileMessageBubble(
            fileName: message.media?.fileName ?? '未知文件',
            isSentByMe: message.isMe,
            fileSize: message.media?.fileSize,
            mimeType: message.media?.mimeType,
            status: status,
            senderId: message.senderId,
            senderName: message.senderName,
            senderAvatar: message.senderAvatar,
            showAvatar: showAvatar,
            onTap: () => _openFile(message),
            onRetry: onRetry,
          ),
        );

      case MessageType.text:
      case MessageType.system:
        return GestureDetector(
          onLongPressStart: (details) => onLongPress(TapDownDetails(globalPosition: details.globalPosition)),
          child: MessageBubble(
            body: message.body,
            timestamp: message.timestamp,
            isSentByMe: message.isMe,
            status: status,
            senderId: message.senderId,
            senderName: message.senderName,
            senderAvatar: message.senderAvatar,
            showSenderName: widget.isGroup && !message.isMe,
            showAvatar: showAvatar,
            onRetry: onRetry,
          ),
        );
    }
  }

  /// 构建编辑/回复指示栏
  Widget _buildEditReplyBar(ImColorScheme colors) {
    final isEditing = _editingMessage != null;
    final message = _editingMessage ?? _replyingMessage;
    if (message == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 图标
          Icon(
            isEditing ? Icons.edit : Icons.reply,
            size: 18,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          // 标签和内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isEditing ? '编辑消息' : '回复 ${message.senderName}',
                  style: TextStyle(
                    color: colors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  message.displayBody,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // 关闭按钮
          GestureDetector(
            onTap: isEditing ? _cancelEdit : _cancelReply,
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 18,
                color: colors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisconnectedBar(ImColorScheme colors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.divider, width: 0.5),
        ),
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 16, color: colors.error),
            const SizedBox(width: 8),
            Text(
              '连接已断开',
              style: TextStyle(color: colors.error),
            ),
          ],
        ),
      ),
    );
  }

  void _previewImage(Message message) {
    // TODO: 实现图片预览
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('图片预览功能开发中')),
    );
  }

  void _playVideo(Message message) {
    // TODO: 实现视频播放
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('视频播放功能开发中')),
    );
  }

  void _openFile(Message message) {
    // TODO: 实现文件打开
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('文件打开功能开发中')),
    );
  }

  void _showChatSettings(BuildContext context) {
    // 群聊直接跳转到群详情页
    if (widget.isGroup) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupDetailPage(
            groupId: widget.conversationId,
            groupName: widget.conversationName,
          ),
        ),
      );
      return;
    }

    // 单聊显示设置菜单
    final colors = ImDesignTokens.colorSchemeOf(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('搜索聊天记录'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('搜索功能开发中')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('消息免打扰'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('清空聊天记录'),
              onTap: () {
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return '昨天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
