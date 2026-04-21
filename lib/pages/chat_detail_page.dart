import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';

import '../providers/im_provider.dart';
import '../sdk/models/message.dart';
import '../sdk/models/media.dart';
import '../sdk/services/voice_recorder_service.dart';
import '../theme/im_design_tokens.dart';
import '../widgets/message_bubbles/message_bubbles.dart';
import '../widgets/input/input.dart';
import '../widgets/im_avatar.dart';
import '../widgets/forward_message_sheet.dart';
import 'group_detail_page.dart';
import 'message_search_page.dart';
import 'media/image_preview_page.dart';
import 'media/video_player_page.dart';
import 'location_viewer_page.dart';

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

  /// 可提及的群成员（用于 @功能）
  List<MentionableMember>? _mentionableMembers;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadDraft();
    if (widget.isGroup) {
      _loadGroupMembers();
    }
    // 进入对话时标记已读
    _markAsRead();
  }

  /// 标记对话消息已读
  Future<void> _markAsRead() async {
    try {
      final service = ref.read(imConnectionServiceProvider);
      await service.markAsRead(widget.conversationId);
      // 同时清除本地未读计数
      ref.read(conversationsProvider.notifier).clearUnread(widget.conversationId);
    } catch (e) {
      debugPrint('[ChatDetail] 标记已读失败: $e');
    }
  }

  /// 加载群成员（用于 @功能）
  Future<void> _loadGroupMembers() async {
    try {
      final service = ref.read(imConnectionServiceProvider);
      final members = await service.getRoomMembers(widget.conversationId);
      if (mounted) {
        setState(() {
          _mentionableMembers = members.map((m) => MentionableMember(
            userBareJid: m.jid,
            nickname: m.nickname ?? m.jid.split('@').first,
          )).toList();
        });
      }
    } catch (e) {
      // 加载失败，静默处理
      debugPrint('[ChatDetail] 加载群成员失败: $e');
    }
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

  /// 转发选中的消息
  Future<void> _forwardSelectedMessages() async {
    if (_selectedMessageIds.isEmpty) return;

    final messages = ref.read(messagesProvider(widget.conversationId));
    final selectedMessages = messages
        .where((m) => _selectedMessageIds.contains(m.id))
        .toList();

    if (selectedMessages.isEmpty) return;

    // 生成预览（显示选中消息数量）
    final preview = selectedMessages.length == 1
        ? _getMessagePreview(selectedMessages.first)
        : '[${selectedMessages.length}条消息]';

    // 显示会话选择器
    final targetConversation = await ForwardMessageSheet.show(
      context: context,
      ref: ref,
      messagePreview: preview,
      excludeConversationId: widget.conversationId,
    );

    if (targetConversation == null) return;

    // 批量转发
    final forwarder = ref.read(messageForwarderProvider);
    int successCount = 0;
    int failCount = 0;

    for (final message in selectedMessages) {
      final result = await forwarder.forwardMessage(
        message: message,
        targetConversationId: targetConversation.id,
        isGroupChat: targetConversation.isGroup,
      );
      if (result.success) {
        successCount++;
      } else {
        failCount++;
      }
    }

    if (!mounted) return;

    // 退出多选模式
    _exitSelectionMode();

    // 显示结果
    if (failCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已转发 $successCount 条消息到 ${targetConversation.name}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转发完成: $successCount 成功, $failCount 失败')),
      );
    }
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
    // 如果有回复消息，创建 ReplyInfo
    ReplyInfo? replyTo;
    if (_replyingMessage != null) {
      replyTo = ReplyInfo(
        messageId: _replyingMessage!.id,
        senderName: _replyingMessage!.senderName,
        body: _replyingMessage!.displayBody,
        messageType: _replyingMessage!.messageType,
      );
      // 清除回复状态
      setState(() {
        _replyingMessage = null;
      });
    }

    await ref
        .read(messagesProvider(widget.conversationId).notifier)
        .sendMessage(text, replyTo: replyTo);
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

  void _onVoiceRecordingComplete(RecordingResult result) {
    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('录音失败: ${result.error}')),
      );
      return;
    }

    if (result.path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('录音文件不存在')),
      );
      return;
    }

    final file = File(result.path!);
    _sendMediaMessage(file, MediaType.audio, duration: result.duration);
  }

  Future<void> _onLocationSelected(Map<String, dynamic> locationData) async {
    final service = ref.read(imConnectionServiceProvider);
    final repository = ref.read(repositoryProvider);
    final currentJid = service.currentJid;

    if (currentJid == null) return;

    final latitude = locationData['latitude'] as double;
    final longitude = locationData['longitude'] as double;
    final address = locationData['address'] as String;

    // 创建位置消息的媒体元数据
    final media = MediaMetadata(
      type: MediaType.file, // 暂时使用file类型，后续可以添加location类型
      latitude: latitude,
      longitude: longitude,
      fileName: address, // 存储地址作为文件名
    );

    // 创建位置消息
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final message = Message(
      id: messageId,
      conversationId: widget.conversationId,
      senderId: currentJid,
      senderName: currentJid.split('@').first,
      body: address,
      timestamp: DateTime.now(),
      isMe: true,
      status: 'sending',
      messageType: MessageType.location, // 使用新的location消息类型
      media: media, // 存储位置信息
    );

    // 保存到数据库
    await repository.saveMessage(message);
    _scrollToBottom();

    try {
      // 发送消息到服务器
      // 位置消息格式: [LOCATION:lat,lng]address
      final isGroup = widget.conversationId.contains('@conference.');
      final messageBody = '[LOCATION:$latitude,$longitude]$address';
      await service.sendMessage(widget.conversationId, messageBody, isGroupChat: isGroup);

      await repository.updateMessageStatus(messageId, 'sent');

      // 更新会话列表
      final existingConversation = ref.read(conversationsProvider).firstWhere(
        (c) => c.id == widget.conversationId,
        orElse: () => throw StateError('Conversation not found'),
      );
      await ref.read(conversationsProvider.notifier).upsertConversation(
        existingConversation.copyWith(
          lastMessage: '[位置] $address',
          lastMessageTime: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('位置发送成功: $address')),
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

  Future<void> _sendMediaMessage(File file, MediaType type, {Duration? duration}) async {
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
      duration: duration != null ? duration.inSeconds : null,
    );

    // 确定消息类型
    final messageType = switch (type) {
      MediaType.image => MessageType.image,
      MediaType.video => MessageType.video,
      MediaType.file => MessageType.file,
      MediaType.audio => MessageType.audio,
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

    // 初始化上传进度
    ref.read(uploadProgressProvider.notifier).updateProgress(messageId, 0.0);

    try {
      // 上传文件到服务器
      final uploadResult = await switch (type) {
        MediaType.image => uploadService.uploadImage(
            messageId: messageId,
            file: file,
            onProgress: (progress) {
              ref.read(uploadProgressProvider.notifier).updateProgress(messageId, progress);
            },
          ),
        MediaType.video => uploadService.uploadVideo(
            messageId: messageId,
            file: file,
            onProgress: (progress) {
              ref.read(uploadProgressProvider.notifier).updateProgress(messageId, progress);
            },
          ),
        MediaType.file => uploadService.uploadFile(
            messageId: messageId,
            file: file,
            mimeType: mimeType,
            onProgress: (progress) {
              ref.read(uploadProgressProvider.notifier).updateProgress(messageId, progress);
            },
          ),
        MediaType.audio => uploadService.uploadAudio(
            messageId: messageId,
            file: file,
            mimeType: mimeType,
            onProgress: (progress) {
              ref.read(uploadProgressProvider.notifier).updateProgress(messageId, progress);
            },
          ),
      };

      if (!uploadResult.success) {
        throw Exception(uploadResult.error ?? '上传失败');
      }

      final remoteUrl = uploadResult.remoteUrl!;

      // 更新媒体元数据（保存远程 URL 和缩略图 URL）
      final updatedMedia = media.copyWith(
        remoteUrl: remoteUrl,
        thumbnailUrl: uploadResult.thumbnailUrl,
      );
      await repository.updateMessageMedia(messageId, updatedMedia);

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

      // 清除上传进度
      ref.read(uploadProgressProvider.notifier).removeProgress(messageId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已发送: $fileName')),
        );
      }
    } catch (e) {
      // 清除上传进度
      ref.read(uploadProgressProvider.notifier).removeProgress(messageId);

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
      MediaType.audio => 'AUDIO',
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
      'm4a' => 'audio/mp4',
      'aac' => 'audio/aac',
      'wav' => 'audio/wav',
      'flac' => 'audio/flac',
      'mp3' => 'audio/mpeg',
      'opus' => 'audio/opus',
      _ => 'application/octet-stream',
    };
  }

  String _getMediaDisplayText(MediaType type, String fileName) {
    return switch (type) {
      MediaType.image => '[图片]',
      MediaType.video => '[视频]',
      MediaType.file => '[文件] $fileName',
      MediaType.audio => '[语音]',
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
  Future<void> _forwardMessage(Message message) async {
    // 获取消息预览文本
    final preview = _getMessagePreview(message);

    // 显示会话选择器
    final targetConversation = await ForwardMessageSheet.show(
      context: context,
      ref: ref,
      messagePreview: preview,
      excludeConversationId: widget.conversationId,
    );

    if (targetConversation == null) return;

    // 执行转发
    final forwarder = ref.read(messageForwarderProvider);
    final result = await forwarder.forwardMessage(
      message: message,
      targetConversationId: targetConversation.id,
      isGroupChat: targetConversation.isGroup,
    );

    if (!mounted) return;

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已转发到 ${targetConversation.name}')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转发失败: ${result.error}')),
      );
    }
  }

  /// 获取消息预览文本
  String _getMessagePreview(Message message) {
    switch (message.messageType) {
      case MessageType.image:
        return '[图片]';
      case MessageType.video:
        return '[视频]';
      case MessageType.file:
        return '[文件] ${message.media?.fileName ?? ''}';
      case MessageType.audio:
        return '[语音]';
      case MessageType.system:
        return '[系统消息]';
      default:
        // 检查是否是位置消息
        if (message.body.startsWith('[LOCATION:')) {
          return '[位置]';
        }
        final body = message.body;
        return body.length > 50 ? '${body.substring(0, 50)}...' : body;
    }
  }

  /// 构建发送者名称（群聊中显示）
  Widget _buildSenderName(String senderName, ImColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 56, bottom: 2),
      child: Text(
        senderName,
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }

  /// 构建消息状态（时间和发送状态）
  Widget _buildMessageStatus(Message message, ImColorScheme colors, bool isMe) {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 0 : 56,
        right: isMe ? 12 : 0,
        top: 4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Text(
            _formatMessageTime(message.timestamp),
            style: TextStyle(
              color: colors.textTertiary,
              fontSize: 11,
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 4),
            _buildMessageStatusIcon(message.status, colors),
          ],
        ],
      ),
    );
  }

  /// 构建消息状态图标
  Widget _buildMessageStatusIcon(String? status, ImColorScheme colors) {
    switch (status) {
      case 'sending':
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: colors.textTertiary,
          ),
        );
      case 'sent':
        return Icon(
          Icons.check,
          size: 12,
          color: colors.textTertiary,
        );
      case 'delivered':
        return Icon(
          Icons.done_all,
          size: 12,
          color: colors.textTertiary,
        );
      case 'read':
        return Icon(
          Icons.done_all,
          size: 12,
          color: colors.primary,
        );
      case 'failed':
        return Icon(
          Icons.error_outline,
          size: 12,
          color: colors.error,
        );
      default:
        return const SizedBox.shrink();
    }
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
              onVoiceRecordingComplete: _onVoiceRecordingComplete,
              onLocationSelected: _onLocationSelected,
              mentionableMembers: widget.isGroup ? _mentionableMembers : null,
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
              onVoiceRecordingComplete: _onVoiceRecordingComplete,
              onLocationSelected: _onLocationSelected,
              mentionableMembers: widget.isGroup ? _mentionableMembers : null,
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

  /// 构建时间分隔栏（微信风格）
  Widget _buildTimeHeader(DateTime time, ImColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      alignment: Alignment.center,
      child: Text(
        _formatMessageTime(time),
        style: TextStyle(
          color: colors.textSecondary,
          fontSize: 12,
        ),
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

    // 日志：检查消息信息
    print('[ChatDetail] Message info - id: ${message.id}, isMe: ${message.isMe}, senderName: ${message.senderName}, body: ${message.body}');

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

    // 获取上传进度
    final uploadProgress = ref.watch(uploadProgressProvider)[message.id];

    // 获取当前用户的 JID
    final service = ref.read(imConnectionServiceProvider);
    final currentJid = service.currentJid;
    final myNickname = currentJid?.split('@').first ?? '';

    // 重新计算 isMe
    bool isMe = message.isMe;
    if (widget.isGroup) {
      // 群聊中，根据发送者名称判断是否是自己发送的消息
      isMe = message.senderName == myNickname;
    } else {
      // 单聊中，根据发送者 ID 判断是否是自己发送的消息
      isMe = message.senderId == currentJid;
    }

    // 日志：检查消息信息
    print('[ChatDetail] Message info - id: ${message.id}, isMe: ${isMe}, senderName: ${message.senderName}, body: ${message.body}');
    print('[ChatDetail] currentJid: $currentJid, myNickname: $myNickname, isGroup: ${widget.isGroup}');

    // 根据消息类型选择气泡
    switch (message.messageType) {
      case MessageType.image:
        // 对于接收的图片消息，URL 存储在 body 中
        // 对于发送的图片消息，优先使用 media.remoteUrl
        final imageUrl = message.media?.remoteUrl ?? _extractMediaUrl(message.body);
        bubble = ImageMessageBubble(
          isSentByMe: isMe,
          localFilePath: message.media?.localFilePath,
          imageUrl: imageUrl,
          width: message.media?.width?.toDouble(),
          height: message.media?.height?.toDouble(),
          status: status,
          uploadProgress: uploadProgress,
          senderId: message.senderId,
          senderName: message.senderName,
          senderAvatar: message.senderAvatar,
          showSenderName: widget.isGroup && !isMe,
          showAvatar: showAvatar,
          onTap: _isSelectionMode ? null : () => _previewImage(message),
          onRetry: onRetry,
        );

      case MessageType.video:
        bubble = VideoMessageBubble(
          isSentByMe: isMe,
          thumbnailUrl: message.media?.thumbnailUrl,
          duration: message.media?.duration,
          width: message.media?.width?.toDouble(),
          height: message.media?.height?.toDouble(),
          status: status,
          uploadProgress: uploadProgress,
          senderId: message.senderId,
          senderName: message.senderName,
          senderAvatar: message.senderAvatar,
          showSenderName: widget.isGroup && !isMe,
          showAvatar: showAvatar,
          onTap: _isSelectionMode ? null : () => _playVideo(message),
          onRetry: onRetry,
        );

      case MessageType.file:
        bubble = FileMessageBubble(
          fileName: message.media?.fileName ?? '未知文件',
          isSentByMe: isMe,
          fileSize: message.media?.fileSize,
          mimeType: message.media?.mimeType,
          status: status,
          uploadProgress: uploadProgress,
          senderId: message.senderId,
          senderName: message.senderName,
          senderAvatar: message.senderAvatar,
          showSenderName: widget.isGroup && !isMe,
          showAvatar: showAvatar,
          onTap: _isSelectionMode ? null : () => _openFile(message),
          onRetry: onRetry,
        );

      case MessageType.audio:
        final audioUrl = message.media?.remoteUrl ?? _extractMediaUrl(message.body);
        bubble = AudioMessageBubble(
          messageId: message.id,
          isSentByMe: isMe,
          audioUrl: audioUrl,
          localFilePath: message.media?.localFilePath,
          duration: message.media?.duration != null
              ? Duration(seconds: message.media!.duration!)
              : null,
          senderId: message.senderId,
          senderName: message.senderName,
          senderAvatar: message.senderAvatar,
          showSenderName: widget.isGroup && !isMe,
          showAvatar: showAvatar,
          status: status,
          onTap: _isSelectionMode ? null : () {},
        );

      case MessageType.system:
        // 系统消息不参与多选
        if (message.body.contains('撤回了一条消息')) {
          return RecalledMessageBubble(
            isSentByMe: isMe,
            senderName: isMe ? null : message.senderName,
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

      case MessageType.location:
        // 处理位置消息
        final latitude = message.media?.latitude;
        final longitude = message.media?.longitude;
        final address = message.body;

        // 创建位置消息气泡（使用标准消息气泡结构）
        bubble = Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 左侧头像（接收的消息）
            if (showAvatar && !isMe) ...[
              ImAvatar.small(
                userId: message.senderId,
                name: message.senderName,
                avatarUrl: message.senderAvatar,
              ),
              const SizedBox(width: 8),
            ],
            // 发送失败图标
            if (isMe && status == MessageDisplayStatus.failed)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 8),
                child: GestureDetector(
                  onTap: onRetry,
                  child: Icon(
                    Icons.error_outline,
                    size: 20,
                    color: colors.error,
                  ),
                ),
              ),
            // 消息气泡
            Flexible(
              child: GestureDetector(
                onTap: () {
                  if (latitude != null && longitude != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => LocationViewerPage(
                          latitude: latitude,
                          longitude: longitude,
                          address: address,
                        ),
                      ),
                    );
                  }
                },
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // 发送者名称（群聊时显示）
                    if (widget.isGroup && !isMe && message.senderName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4, left: 12),
                        child: Text(
                          message.senderName!,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMe ? colors.primary : colors.surfaceVariant,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                          bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                color: isMe ? Colors.white : colors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  address,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : colors.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${latitude?.toStringAsFixed(6)}, ${longitude?.toStringAsFixed(6)}',
                            style: TextStyle(
                              color: isMe ? Colors.white.withOpacity(0.8) : colors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 消息状态
                    Padding(
                      padding: EdgeInsets.only(
                        left: isMe ? 0 : 12,
                        right: isMe ? 12 : 0,
                        top: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                        children: [
                          Text(
                            _formatMessageTime(message.timestamp),
                            style: TextStyle(
                              color: colors.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 4),
                            _buildMessageStatusIcon(message.status, colors),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 右侧头像（自己发送的消息）
            if (showAvatar && isMe) ...[
              const SizedBox(width: 8),
              ImAvatar.small(
                userId: message.senderId,
                name: message.senderName,
                avatarUrl: message.senderAvatar,
              ),
            ],
          ],
        );
        break;

      case MessageType.text:
        // 检查是否是旧格式的位置消息（用于兼容）
        bool isOldLocationMessage = message.body.startsWith('[LOCATION:');
        if (isOldLocationMessage) {
          // 解析位置信息
          final locationMatch = RegExp(r'^\[LOCATION:([^,]+),([^\]]+)\](.+)$').firstMatch(message.body);
          if (locationMatch != null) {
            final latitude = double.tryParse(locationMatch.group(1) ?? '');
            final longitude = double.tryParse(locationMatch.group(2) ?? '');
            final address = locationMatch.group(3) ?? '';
            
            // 创建位置消息气泡
            bubble = Container(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (widget.isGroup && !isMe) _buildSenderName(message.senderName, colors),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isMe ? colors.primary : colors.surfaceVariant,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                        bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              color: isMe ? Colors.white : colors.primary,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                address,
                                style: TextStyle(
                                  color: isMe ? Colors.white : colors.textPrimary,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${latitude?.toStringAsFixed(6)}, ${longitude?.toStringAsFixed(6)}',
                          style: TextStyle(
                            color: isMe ? Colors.white.withOpacity(0.8) : colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildMessageStatus(message, colors, isMe),
                ],
              ),
            );
            break;
          }
        }
        
        // 回复消息使用 ReplyMessageBubble（Light-1-Client 样式）
        if (message.replyTo != null) {
          bubble = ReplyMessageBubble(
            text: message.body,
            replyInfo: message.replyTo!,
            isSentByMe: isMe,
            timestamp: message.timestamp,
            status: message.status,
            senderId: message.senderId,
            senderName: message.senderName,
            senderAvatar: message.senderAvatar,
            showSenderName: widget.isGroup && !isMe,
            showAvatar: showAvatar,
            onRetry: onRetry,
          );
        } else {
          bubble = MessageBubble(
            body: message.body,
            timestamp: message.timestamp,
            isSentByMe: isMe,
            status: status,
            senderId: message.senderId,
            senderName: message.senderName,
            senderAvatar: message.senderAvatar,
            showSenderName: widget.isGroup && !isMe,
            showAvatar: showAvatar,
            isEdited: message.isEdited,
            onRetry: onRetry,
          );
        }
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
  ///
  /// Light-1-Client 样式：
  /// - 左侧彩色指示条（4px x 32px）
  /// - surfaceVariant 背景
  /// - 底部边框
  Widget _buildEditReplyBar(ImColorScheme colors) {
    final isEditing = _editingMessage != null;
    final message = _editingMessage ?? _replyingMessage;
    if (message == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        border: Border(
          bottom: BorderSide(color: colors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // 左侧指示条（Light-1-Client 样式）
          Container(
            width: 4,
            height: 32,
            decoration: BoxDecoration(
              color: isEditing ? colors.primary : colors.textSecondary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 2),
                Text(
                  message.displayBody,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14, // Light-1-Client: 14px
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
                size: 20,
                color: colors.textSecondary,
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

  /// 从消息体提取媒体 URL
  ///
  /// 支持两种格式:
  /// - 直接 URL: http://...
  /// - 带标签格式: [IMG:filename]http://... 或 [VIDEO:filename]http://... 或 [AUDIO:filename]http://...
  String? _extractMediaUrl(String body) {
    if (body.startsWith('http://') || body.startsWith('https://')) {
      return body;
    }
    // 匹配 [TYPE:filename]url 格式
    final regex = RegExp(r'^\[(IMG|VIDEO|FILE|AUDIO):[^\]]+\](.+)$');
    final match = regex.firstMatch(body);
    if (match != null) {
      return match.group(2);
    }
    return null;
  }

  void _previewImage(Message message) {
    // 获取图片 URL（优先使用 media.remoteUrl，其次使用 body）
    final imageUrl = message.media?.remoteUrl ?? _extractMediaUrl(message.body);

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
    final videoUrl = message.media?.remoteUrl ?? _extractMediaUrl(message.body);

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
    final remoteUrl = message.media?.remoteUrl ?? _extractMediaUrl(message.body);

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

  /// 格式化时间分隔符文本（微信风格）
  ///
  /// 显示规则：
  /// - 今天：14:30
  /// - 昨天：昨天 14:30
  /// - 本周：星期一 14:30
  /// - 今年：12月15日 14:30
  /// - 更早：2024年12月15日 14:30
  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(time.year, time.month, time.day);
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    if (messageDate == today) {
      // 今天只显示时间
      return timeStr;
    } else if (messageDate == yesterday) {
      // 昨天
      return '昨天 $timeStr';
    } else if (today.difference(messageDate).inDays < 7) {
      // 本周显示星期几
      return '${_getWeekday(time.weekday)} $timeStr';
    } else if (time.year == now.year) {
      // 今年显示月日
      return '${time.month}月${time.day}日 $timeStr';
    } else {
      // 更早显示完整日期
      return '${time.year}年${time.month}月${time.day}日 $timeStr';
    }
  }

  /// 获取星期几的中文名称
  String _getWeekday(int weekday) {
    const weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
    return weekdays[weekday - 1];
  }
}
