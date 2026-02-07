import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/im_provider.dart';
import '../sdk/models/message.dart';
import '../sdk/models/media.dart';
import '../theme/im_design_tokens.dart';
import '../widgets/message_bubbles/message_bubbles.dart';
import '../widgets/input/input.dart';

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
          // 输入区域
          if (isConnected)
            MessageInputArea(
              key: _inputKey,
              onSend: _sendTextMessage,
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
    return Center(
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
        ],
      ),
    );
  }

  Widget _buildMessageList(List<Message> messages, ImColorScheme colors) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
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

    // 根据消息类型选择气泡
    switch (message.messageType) {
      case MessageType.image:
        return ImageMessageBubble(
          isSentByMe: message.isMe,
          localFilePath: message.media?.localFilePath,
          imageUrl: message.media?.remoteUrl,
          width: message.media?.width?.toDouble(),
          height: message.media?.height?.toDouble(),
          status: status,
          onTap: () => _previewImage(message),
        );

      case MessageType.video:
        return VideoMessageBubble(
          isSentByMe: message.isMe,
          thumbnailPath: message.media?.thumbnailUrl,
          thumbnailUrl: message.media?.thumbnailUrl,
          duration: message.media?.duration,
          width: message.media?.width?.toDouble(),
          height: message.media?.height?.toDouble(),
          status: status,
          onTap: () => _playVideo(message),
        );

      case MessageType.file:
        return FileMessageBubble(
          fileName: message.media?.fileName ?? '未知文件',
          isSentByMe: message.isMe,
          fileSize: message.media?.fileSize,
          mimeType: message.media?.mimeType,
          status: status,
          onTap: () => _openFile(message),
        );

      case MessageType.text:
      case MessageType.system:
        return MessageBubble(
          body: message.body,
          timestamp: message.timestamp,
          isSentByMe: message.isMe,
          status: status,
          senderName: message.senderName,
          showSenderName: widget.isGroup && !message.isMe,
        );
    }
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
            if (widget.isGroup)
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('群聊设置'),
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
