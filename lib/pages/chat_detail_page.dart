import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';

import '../providers/im_provider.dart';
import '../sdk/models/message.dart';
import '../sdk/models/media.dart';
import '../theme/im_design_tokens.dart';
import '../widgets/message_bubbles/message_bubbles.dart';
import '../widgets/input/input.dart';
import 'group_detail_page.dart';
import 'message_search_page.dart';
import 'media/image_preview_page.dart';
import 'media/video_player_page.dart';

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

  /// 是否处于多选模式
  bool _isSelectionMode = false;

  /// 选中的消息 ID 集合
  final Set<String> _selectedMessageIds = {};

  /// 初始草稿文本
  String? _initialDraft;

  /// 草稿保存防抖计时器
  Timer? _draftSaveTimer;

  /// 当前输入的文本（用于保存草稿）
  String _currentInputText = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadDraft();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _draftSaveTimer?.cancel();
    // 离开页面时保存草稿
    _saveDraftImmediately();
    super.dispose();
  }

  /// 加载草稿
  Future<void> _loadDraft() async {
    final repository = ref.read(repositoryProvider);
    final draft = await repository.getDraft(widget.conversationId);
    if (draft != null && draft.isNotEmpty && mounted) {
      setState(() {
        _initialDraft = draft;
        _currentInputText = draft;
      });
    }
  }

  /// 文本变化时保存草稿（防抖）并发送输入状态
  void _onInputTextChanged(String text) {
    _currentInputText = text;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(const Duration(seconds: 1), () {
      _saveDraftImmediately();
    });

    // 通知输入状态服务
    final typingService = ref.read(typingIndicatorServiceProvider);
    if (text.isNotEmpty) {
      typingService.onLocalTyping(widget.conversationId);
    } else {
      typingService.onLocalTypingStopped(widget.conversationId);
    }
  }

  /// 立即保存草稿
  void _saveDraftImmediately() {
    final repository = ref.read(repositoryProvider);
    if (_currentInputText.isNotEmpty) {
      repository.saveDraft(widget.conversationId, _currentInputText);
    } else {
      repository.clearDraft(widget.conversationId);
    }
  }

  /// 清除草稿
  Future<void> _clearDraft() async {
    _currentInputText = '';
    _draftSaveTimer?.cancel();
    final repository = ref.read(repositoryProvider);
    await repository.clearDraft(widget.conversationId);
  }

  // ========== 多选模式 ==========

  /// 进入多选模式
  void _enterSelectionMode(String messageId) {
    setState(() {
      _isSelectionMode = true;
      _selectedMessageIds.clear();
      _selectedMessageIds.add(messageId);
    });
  }

  /// 退出多选模式
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedMessageIds.clear();
    });
  }

  /// 切换消息选中状态
  void _toggleMessageSelection(String messageId) {
    setState(() {
      if (_selectedMessageIds.contains(messageId)) {
        _selectedMessageIds.remove(messageId);
        // 如果没有选中任何消息，退出多选模式
        if (_selectedMessageIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedMessageIds.add(messageId);
      }
    });
  }

  /// 全选
  void _selectAll(List<Message> messages) {
    setState(() {
      _selectedMessageIds.clear();
      for (final msg in messages) {
        _selectedMessageIds.add(msg.id);
      }
    });
  }

  /// 批量删除选中的消息
  Future<void> _deleteSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除消息'),
        content: Text('确定要删除选中的 ${_selectedMessageIds.length} 条消息吗？'),
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
      final notifier = ref.read(messagesProvider(widget.conversationId).notifier);
      for (final id in _selectedMessageIds.toList()) {
        await notifier.deleteMessage(id);
      }
      _exitSelectionMode();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已删除选中的消息')),
        );
      }
    }
  }

  /// 转发选中的消息（显示提示）
  void _forwardSelectedMessages() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('转发功能开发中')),
    );
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
    // 发送成功后清除草稿
    await _clearDraft();
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

  Future<void> _sendMediaMessage(File file, MediaType type) async {
    final service = ref.read(imConnectionServiceProvider);
    final repository = ref.read(repositoryProvider);
    final uploadService = ref.read(mediaUploadServiceProvider);
    final currentJid = service.currentJid;

    if (currentJid == null) return;

    // 获取文件信息
    final fileName = file.path.split('/').last;
    final fileSize = await file.length();
    final mimeType = _getMimeType(fileName);

    // 创建媒体元数据
    final media = MediaMetadata(
      type: type,
      localFilePath: file.path,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: fileSize,
    );

    // 确定消息类型
    final messageType = switch (type) {
      MediaType.image => MessageType.image,
      MediaType.video => MessageType.video,
      MediaType.file => MessageType.file,
    };

    final messageId = DateTime.now().millisecondsSinceEpoch.toString();

    // 创建本地消息
    final message = Message(
      id: messageId,
      conversationId: widget.conversationId,
      senderId: currentJid,
      senderName: currentJid.split('@').first,
      body: _getMediaDisplayText(type, fileName),
      timestamp: DateTime.now(),
      isMe: true,
      status: 'uploading',
      messageType: messageType,
      media: media,
    );

    // 保存到数据库
    await repository.saveMessage(message);
    _scrollToBottom();

    try {
      // 上传文件到服务器
      final uploadResult = await switch (type) {
        MediaType.image => uploadService.uploadImage(
            messageId: messageId,
            file: file,
            onProgress: (progress) {
              // 可以在这里更新上传进度 UI
            },
          ),
        MediaType.video => uploadService.uploadVideo(
            messageId: messageId,
            file: file,
          ),
        MediaType.file => uploadService.uploadFile(
            messageId: messageId,
            file: file,
            mimeType: mimeType,
          ),
      };

      if (!uploadResult.success) {
        throw Exception(uploadResult.error ?? '上传失败');
      }

      final remoteUrl = uploadResult.remoteUrl!;

      // 发送消息到服务器
      // 消息格式: [TYPE:filename]url
      // 例如: [IMG:photo.jpg]http://server/image.jpg
      final isGroup = widget.conversationId.contains('@conference.');
      final messageBody = _formatMediaMessage(type, remoteUrl, fileName);
      await service.sendMessage(widget.conversationId, messageBody, isGroupChat: isGroup);

      // 更新消息体为包含 URL 的内容，方便本地显示
      await repository.updateMessageBody(messageId, messageBody);
      await repository.updateMessageStatus(messageId, 'sent');

      // 更新会话列表
      final displayText = _getMediaDisplayText(type, fileName);
      final existingConversation = ref.read(conversationsProvider).firstWhere(
        (c) => c.id == widget.conversationId,
        orElse: () => throw StateError('Conversation not found'),
      );
      await ref.read(conversationsProvider.notifier).upsertConversation(
        existingConversation.copyWith(
          lastMessage: displayText,
          lastMessageTime: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已发送: $fileName')),
        );
      }
    } catch (e) {
      await repository.updateMessageStatus(messageId, 'failed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }

  /// 格式化媒体消息内容
  /// 格式: [TYPE:filename]url
  String _formatMediaMessage(MediaType type, String url, String fileName) {
    final typeTag = switch (type) {
      MediaType.image => 'IMG',
      MediaType.video => 'VIDEO',
      MediaType.file => 'FILE',
    };
    return '[$typeTag:$fileName]$url';
  }

  String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'zip' => 'application/zip',
      'rar' => 'application/x-rar-compressed',
      _ => 'application/octet-stream',
    };
  }

  String _getMediaDisplayText(MediaType type, String fileName) {
    return switch (type) {
      MediaType.image => '[图片]',
      MediaType.video => '[视频]',
      MediaType.file => '[文件] $fileName',
    };
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
      case MessageMenuAction.multiSelect:
        _enterSelectionMode(message.id);
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
      appBar: _isSelectionMode
          ? _buildSelectionAppBar(colors, messages)
          : _buildNormalAppBar(colors),
      backgroundColor: colors.background,
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: messages.isEmpty
                ? _buildEmptyState(colors)
                : _buildMessageList(messages, colors),
          ),
          // 多选模式工具栏
          if (_isSelectionMode)
            _buildSelectionToolbar(colors)
          // 编辑/回复模式：显示指示栏 + 输入框
          else if (_editingMessage != null || _replyingMessage != null) ...[
            _buildEditReplyBar(colors),
            MessageInputArea(
              key: _inputKey,
              onSend: _editingMessage != null
                  ? _submitEdit
                  : _sendTextMessage,
              initialText: _initialDraft,
              onTextChanged: _onInputTextChanged,
              onImageSelected: _onImageSelected,
              onMultipleImagesSelected: _onMultipleImagesSelected,
              onVideoSelected: _onVideoSelected,
              onFileSelected: _onFileSelected,
            ),
          ]
          // 普通输入区域
          else if (isConnected)
            MessageInputArea(
              key: _inputKey,
              onSend: _sendTextMessage,
              initialText: _initialDraft,
              onTextChanged: _onInputTextChanged,
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

  /// 构建普通 AppBar
  PreferredSizeWidget _buildNormalAppBar(ImColorScheme colors) {
    // 监听输入状态
    final typingService = ref.watch(typingIndicatorServiceProvider);
    final isTyping = typingService.isTyping(widget.conversationId);

    return AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.conversationName),
          if (isTyping)
            Text(
              '对方正在输入...',
              style: TextStyle(
                fontSize: 12,
                color: colors.primary,
                fontStyle: FontStyle.italic,
              ),
            )
          else if (widget.isGroup)
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
    );
  }

  /// 构建多选模式 AppBar
  PreferredSizeWidget _buildSelectionAppBar(ImColorScheme colors, List<Message> messages) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectionMode,
      ),
      title: Text('已选择 ${_selectedMessageIds.length} 条'),
      backgroundColor: colors.surface,
      elevation: 0.5,
      actions: [
        TextButton(
          onPressed: _selectedMessageIds.length == messages.length
              ? null
              : () => _selectAll(messages),
          child: Text(
            '全选',
            style: TextStyle(
              color: _selectedMessageIds.length == messages.length
                  ? colors.textDisabled
                  : colors.primary,
            ),
          ),
        ),
      ],
    );
  }

  /// 构建多选模式底部工具栏
  Widget _buildSelectionToolbar(ImColorScheme colors) {
    final hasSelection = _selectedMessageIds.isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.divider, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildToolbarButton(
            icon: Icons.delete_outline,
            label: '删除',
            color: hasSelection ? Colors.red : colors.textDisabled,
            onTap: hasSelection ? _deleteSelectedMessages : null,
          ),
          _buildToolbarButton(
            icon: Icons.forward,
            label: '转发',
            color: hasSelection ? colors.textPrimary : colors.textDisabled,
            onTap: hasSelection ? _forwardSelectedMessages : null,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
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
      if (_isSelectionMode) {
        // 多选模式下长按也切换选中
        _toggleMessageSelection(message.id);
      } else {
        // 非多选模式下显示菜单
        _showMessageMenu(message, details.globalPosition);
      }
    }

    // 点击回调（多选模式下切换选中）
    void onTapInSelectionMode() {
      _toggleMessageSelection(message.id);
    }

    // 重试回调
    void onRetry() {
      _retryMessage(message);
    }

    // 构建消息气泡内容
    Widget bubble;

    // 根据消息类型选择气泡
    switch (message.messageType) {
      case MessageType.image:
        // 对于接收的图片消息，URL 存储在 body 中
        // 对于发送的图片消息，优先使用 media.remoteUrl
        final imageUrl = message.media?.remoteUrl ??
            (message.body.startsWith('http') ? message.body : null);
        bubble = ImageMessageBubble(
          isSentByMe: message.isMe,
          localFilePath: message.media?.localFilePath,
          imageUrl: imageUrl,
          width: message.media?.width?.toDouble(),
          height: message.media?.height?.toDouble(),
          status: status,
          senderId: message.senderId,
          senderName: message.senderName,
          senderAvatar: message.senderAvatar,
          showAvatar: showAvatar,
          onTap: _isSelectionMode ? null : () => _previewImage(message),
          onRetry: onRetry,
        );

      case MessageType.video:
        bubble = VideoMessageBubble(
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
          onTap: _isSelectionMode ? null : () => _playVideo(message),
          onRetry: onRetry,
        );

      case MessageType.file:
        bubble = FileMessageBubble(
          fileName: message.media?.fileName ?? '未知文件',
          isSentByMe: message.isMe,
          fileSize: message.media?.fileSize,
          mimeType: message.media?.mimeType,
          status: status,
          senderId: message.senderId,
          senderName: message.senderName,
          senderAvatar: message.senderAvatar,
          showAvatar: showAvatar,
          onTap: _isSelectionMode ? null : () => _openFile(message),
          onRetry: onRetry,
        );

      case MessageType.system:
        // 系统消息不参与多选
        if (message.body.contains('撤回了一条消息')) {
          return RecalledMessageBubble(
            isSentByMe: message.isMe,
            senderName: message.isMe ? null : message.senderName,
          );
        }
        return Center(
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: colors.surfaceVariant.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              message.body,
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        );

      case MessageType.text:
        bubble = MessageBubble(
          body: message.body,
          timestamp: message.timestamp,
          isSentByMe: message.isMe,
          status: status,
          senderId: message.senderId,
          senderName: message.senderName,
          senderAvatar: message.senderAvatar,
          showSenderName: widget.isGroup && !message.isMe,
          showAvatar: showAvatar,
          isEdited: message.isEdited,
          onRetry: onRetry,
        );
    }

    // 包装手势检测和多选 UI
    final isSelected = _selectedMessageIds.contains(message.id);

    Widget result = GestureDetector(
      onTap: _isSelectionMode ? onTapInSelectionMode : null,
      onLongPressStart: (details) {
        if (_isSelectionMode) {
          // 多选模式下长按切换选中
          _toggleMessageSelection(message.id);
        } else {
          // 非多选模式下显示菜单
          _showMessageMenu(message, details.globalPosition);
        }
      },
      onSecondaryTapDown: (details) => onLongPress(details),
      child: bubble,
    );

    // 多选模式下添加复选框
    if (_isSelectionMode) {
      result = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 复选框
          GestureDetector(
            onTap: onTapInSelectionMode,
            child: Container(
              width: 40,
              alignment: Alignment.center,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? colors.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.textTertiary,
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ),
          // 消息气泡
          Expanded(child: result),
        ],
      );
    }

    return result;
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
    // 获取图片 URL（优先使用 media.remoteUrl，其次使用 body）
    final imageUrl = message.media?.remoteUrl ??
        (message.body.startsWith('http') ? message.body : null);

    if (imageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取图片地址')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewPage(
          imageUrl: imageUrl,
          heroTag: 'image_${message.id}',
          fileName: message.media?.fileName,
          localFilePath: message.media?.localFilePath,
        ),
      ),
    );
  }

  void _playVideo(Message message) {
    // 获取视频 URL（优先使用 media.remoteUrl，其次使用 body）
    final videoUrl = message.media?.remoteUrl ??
        (message.body.startsWith('http') ? message.body : null);

    if (videoUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取视频地址')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerPage(
          videoUrl: videoUrl,
          localFilePath: message.media?.localFilePath,
          title: message.media?.fileName,
        ),
      ),
    );
  }

  Future<void> _openFile(Message message) async {
    // 优先使用本地文件
    String? filePath = message.media?.localFilePath;

    if (filePath != null && filePath.isNotEmpty) {
      // 去除 file:// 前缀
      if (filePath.startsWith('file://')) {
        filePath = filePath.substring(7);
      }

      final file = File(filePath);
      if (await file.exists()) {
        try {
          await OpenFile.open(filePath);
          return;
        } catch (e) {
          // 本地打开失败，尝试远程 URL
        }
      }
    }

    // 使用远程 URL
    final remoteUrl = message.media?.remoteUrl ??
        (message.body.startsWith('http') ? message.body : null);

    if (remoteUrl != null) {
      try {
        await OpenFile.open(remoteUrl);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法打开文件: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法获取文件地址')),
        );
      }
    }
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
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MessageSearchPage(
                      conversationId: widget.conversationId,
                      conversationName: widget.conversationName,
                    ),
                  ),
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
