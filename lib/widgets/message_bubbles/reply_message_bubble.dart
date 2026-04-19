/// 回复消息气泡组件
///
/// 功能：
/// - 显示回复内容 + 引用区域
/// - 引用区域在消息下方（微信样式）
/// - 支持图片/视频缩略图预览
/// - 支持已撤回/已删除状态
/// - 支持头像、发送者名称、时间状态显示
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../sdk/models/message.dart';
import '../../theme/im_design_tokens.dart';
import '../../theme/message_styles.dart';
import '../im_avatar.dart';
import '../message_status_widget.dart';
import 'message_bubble.dart';

/// 回复消息气泡
///
/// 展示带引用的消息样式，包含被回复消息的预览和实际回复内容
/// 微信样式：消息气泡在上方，引用区域在下方
class ReplyMessageBubble extends StatelessWidget {
  const ReplyMessageBubble({
    super.key,
    required this.text,
    required this.replyInfo,
    required this.isSentByMe,
    required this.timestamp,
    this.status,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.showSenderName = false,
    this.showAvatar = true,
    this.onReplyTap,
    this.onLongPress,
    this.onRetry,
  });

  /// 回复消息的文本内容
  final String text;

  /// 被回复的消息信息
  final ReplyInfo replyInfo;

  /// 是否是自己发送的
  final bool isSentByMe;

  /// 时间戳
  final DateTime timestamp;

  /// 消息状态
  final String? status;

  /// 发送者 ID
  final String? senderId;

  /// 发送者名称
  final String? senderName;

  /// 发送者头像
  final String? senderAvatar;

  /// 是否显示发送者名称
  final bool showSenderName;

  /// 是否显示头像
  final bool showAvatar;

  /// 点击引用区域的回调
  final VoidCallback? onReplyTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 重试回调
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);
    final maxWidth = MediaQuery.of(context).size.width * 0.65;
    final bubbleColor = isSentByMe
        ? colors.messageBubbleSent
        : colors.messageBubbleReceived;

    // 解析状态
    MessageDisplayStatus? displayStatus;
    switch (status) {
      case 'sending':
        displayStatus = MessageDisplayStatus.sending;
        break;
      case 'sent':
        displayStatus = MessageDisplayStatus.sent;
        break;
      case 'delivered':
        displayStatus = MessageDisplayStatus.delivered;
        break;
      case 'read':
        displayStatus = MessageDisplayStatus.read;
        break;
      case 'failed':
        displayStatus = MessageDisplayStatus.failed;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧头像（接收的消息）
          if (showAvatar && !isSentByMe) ...[
            ImAvatar.small(
              userId: senderId ?? '',
              name: senderName,
              avatarUrl: senderAvatar,
            ),
            const SizedBox(width: 8),
          ],
          // 发送失败图标（自己发送的消息，显示在左侧）
          if (isSentByMe && displayStatus == MessageDisplayStatus.failed)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 8),
              child: MessageFailedIndicator(
                onRetry: onRetry ?? () {},
                size: 20,
              ),
            ),
          // 消息内容区域
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 消息气泡
                GestureDetector(
                  onLongPress: onLongPress,
                  child: Container(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    padding: MessageStyles.bubblePadding,
                    decoration: MessageStyles.bubble(
                      bubbleColor,
                      radius: isSentByMe
                          ? MessageStyles.bubbleRadiusSent
                          : MessageStyles.bubbleRadiusReceived,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 发送者名称（群聊时显示）
                        if (showSenderName && senderName != null && !isSentByMe)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              senderName!,
                              style: MessageStyles.senderName(colors.primary),
                            ),
                          ),
                        // 消息内容
                        Text(
                          text,
                          style: TextStyle(
                            color: isSentByMe ? Colors.black87 : colors.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                        // 消息状态（自己发送的消息显示）
                        if (isSentByMe && displayStatus != null && displayStatus != MessageDisplayStatus.failed)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildStatusIcon(colors, displayStatus),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // 引用区域（在消息下方）
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onReplyTap,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: maxWidth,
                      maxHeight: 28, // Light-1-Client: 引用气泡高度最高 28px
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2), // Light-1-Client: #F2F2F2
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: _buildQuotedContent(colors),
                  ),
                ),
              ],
            ),
          ),
          // 右侧头像（自己发送的消息）
          if (showAvatar && isSentByMe) ...[
            const SizedBox(width: 8),
            ImAvatar.small(
              userId: senderId ?? '',
              name: senderName,
              avatarUrl: senderAvatar,
            ),
          ],
        ],
      ),
    );
  }

  /// 构建底部（时间 + 状态）
  Widget _buildFooter(ImColorScheme colors, MessageDisplayStatus? displayStatus) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(timestamp),
          style: TextStyle(
            color: isSentByMe ? Colors.black45 : colors.textTertiary,
            fontSize: 11,
          ),
        ),
        if (isSentByMe && displayStatus != null) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(colors, displayStatus),
        ],
      ],
    );
  }

  /// 构建消息状态图标
  Widget _buildStatusIcon(ImColorScheme colors, MessageDisplayStatus status) {
    switch (status) {
      case MessageDisplayStatus.sending:
        return SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation(colors.textTertiary),
          ),
        );
      case MessageDisplayStatus.sent:
        return Icon(Icons.check, size: 14, color: colors.textTertiary);
      case MessageDisplayStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: colors.textTertiary);
      case MessageDisplayStatus.read:
        return Icon(Icons.done_all, size: 14, color: colors.info);
      case MessageDisplayStatus.failed:
        return const SizedBox.shrink();
    }
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// 构建引用内容区域
  ///
  /// Light-1-Client 样式：
  /// - 字号 14px
  /// - 颜色 #666666
  /// - 行高 1.57
  /// - 格式：「发送者：消息内容」
  Widget _buildQuotedContent(ImColorScheme colors) {
    // Light-1-Client: 引用文字颜色 #666666
    const textColor = Color(0xFF666666);
    const textStyle = TextStyle(
      fontSize: 14, // Light-1-Client: 14px
      color: textColor,
      height: 1.57, // Light-1-Client: lineHeight 1.57
    );

    // 已撤回
    if (replyInfo.isRetracted) {
      return Text(
        '${replyInfo.senderName}：消息已撤回',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: textStyle.copyWith(fontStyle: FontStyle.italic),
      );
    }

    // 根据消息类型渲染
    switch (replyInfo.messageType) {
      case MessageType.image:
        return _buildMediaQuote(
          colors,
          icon: Icons.image,
          label: '[图片]',
          thumbnailUrl: replyInfo.thumbnailUrl ?? replyInfo.mediaUrl,
        );
      case MessageType.video:
        return _buildMediaQuote(
          colors,
          icon: Icons.videocam,
          label: '[视频]',
          thumbnailUrl: replyInfo.thumbnailUrl,
          showPlayIcon: true,
        );
      case MessageType.file:
        final fileName = replyInfo.fileName ?? '文件';
        return Text(
          '${replyInfo.senderName}：[文件] $fileName',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        );
      case MessageType.audio:
        return Text(
          '${replyInfo.senderName}：[语音]',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        );
      case MessageType.system:
        return Text(
          '${replyInfo.senderName}：[系统消息]',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        );
      case MessageType.text:
        final body = replyInfo.body.length > 100
            ? '${replyInfo.body.substring(0, 100)}...'
            : replyInfo.body;
        return Text(
          '${replyInfo.senderName}：$body',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyle,
        );
    }
  }

  /// 构建媒体类型的引用（图片/视频）
  Widget _buildMediaQuote(
    ImColorScheme colors, {
    required IconData icon,
    required String label,
    String? thumbnailUrl,
    bool showPlayIcon = false,
  }) {
    // Light-1-Client: 引用文字颜色 #666666
    const textColor = Color(0xFF666666);
    const textStyle = TextStyle(
      fontSize: 14, // Light-1-Client: 14px
      color: textColor,
      height: 1.57, // Light-1-Client: lineHeight 1.57
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 文字部分
        Flexible(
          child: Text(
            '${replyInfo.senderName}：$label',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ),
        // 缩略图
        if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) ...[
          const SizedBox(width: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 24,
                    height: 24,
                    color: colors.surfaceVariant,
                    child: Icon(icon, size: 14, color: Colors.grey),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 24,
                    height: 24,
                    color: colors.surfaceVariant,
                    child: Icon(icon, size: 14, color: Colors.grey),
                  ),
                ),
              ),
              // 视频播放图标
              if (showPlayIcon)
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    size: 8,
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
