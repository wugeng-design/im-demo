import 'package:flutter/material.dart';

import '../../sdk/models/message.dart';
import '../../theme/im_design_tokens.dart';
import '../../theme/message_styles.dart';
import '../im_avatar.dart';
import '../message_status_widget.dart';
import 'quote_bubble.dart';

/// 消息状态
enum MessageDisplayStatus {
  sending,
  sent,
  delivered,
  read,
  failed,
}

/// 文本消息气泡
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.body,
    required this.timestamp,
    required this.isSentByMe,
    this.status,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.showSenderName = false,
    this.showAvatar = false,
    this.isEdited = false,
    this.replyTo,
    this.onLongPress,
    this.onTap,
    this.onRetry,
    this.onAvatarTap,
    this.onQuoteTap,
  });

  /// 消息内容
  final String body;

  /// 时间戳
  final DateTime timestamp;

  /// 是否是自己发送的
  final bool isSentByMe;

  /// 消息状态
  final MessageDisplayStatus? status;

  /// 发送者 ID（用于头像占位符颜色）
  final String? senderId;

  /// 发送者名称（群聊时显示）
  final String? senderName;

  /// 发送者头像 URL
  final String? senderAvatar;

  /// 是否显示发送者名称
  final bool showSenderName;

  /// 是否显示头像
  final bool showAvatar;

  /// 是否已编辑
  final bool isEdited;

  /// 回复消息信息
  final ReplyInfo? replyTo;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 点击回调
  final VoidCallback? onTap;

  /// 重试回调
  final VoidCallback? onRetry;

  /// 头像点击回调
  final VoidCallback? onAvatarTap;

  /// 引用消息点击回调
  final VoidCallback? onQuoteTap;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧头像（接收的消息）
          if (showAvatar && !isSentByMe) ...[
            GestureDetector(
              onTap: onAvatarTap,
              child: ImAvatar.small(
                userId: senderId ?? '',
                name: senderName,
                avatarUrl: senderAvatar,
              ),
            ),
            const SizedBox(width: 8),
          ],
          // 发送失败图标（自己发送的消息，显示在左侧）
          // 同步自 Light-1-Client: 微信风格红色圆形背景 + 白色感叹号
          if (isSentByMe && status == MessageDisplayStatus.failed)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 8),
              child: MessageFailedIndicator(
                onRetry: onRetry ?? () {},
                size: 20,
              ),
            ),
          // 消息气泡
          Flexible(
            child: GestureDetector(
              onLongPress: onLongPress,
              onTap: onTap,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.65,
                ),
                padding: MessageStyles.bubblePadding,
                decoration: MessageStyles.bubble(
                  isSentByMe
                      ? colors.messageBubbleSent
                      : colors.messageBubbleReceived,
                  radius: isSentByMe
                      ? MessageStyles.bubbleRadiusSent
                      : MessageStyles.bubbleRadiusReceived,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                    // 引用消息气泡
                    if (replyTo != null)
                      QuoteBubble(
                        replyInfo: replyTo!,
                        isSentByMe: isSentByMe,
                        onTap: onQuoteTap,
                      ),
                    // 消息内容
                    Text(
                      body,
                      style: TextStyle(
                        color: isSentByMe ? Colors.black87 : colors.textPrimary,
                        fontSize: 15,
                      ),
                    ),
                    // 时间和状态（微信风格：不显示）
                    // const SizedBox(height: 4),
                    // _buildFooter(colors),
                  ],
                ),
              ),
            ),
          ),
          // 右侧头像（自己发送的消息）
          if (showAvatar && isSentByMe) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAvatarTap,
              child: ImAvatar.small(
                userId: senderId ?? '',
                name: senderName,
                avatarUrl: senderAvatar,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建底部（时间 + 状态 + 已编辑标记）
  Widget _buildFooter(ImColorScheme colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 已编辑标记
        if (isEdited) ...[
          Text(
            '已编辑',
            style: TextStyle(
              color: isSentByMe ? Colors.black45 : colors.textTertiary,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          _formatTime(timestamp),
          style: TextStyle(
            color: isSentByMe ? Colors.black45 : colors.textTertiary,
            fontSize: 11,
          ),
        ),
        if (isSentByMe && status != null) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(colors),
        ],
      ],
    );
  }

  /// 构建消息状态图标
  /// 同步自 Light-1-Client 样式
  Widget _buildStatusIcon(ImColorScheme colors) {
    switch (status!) {
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
        // 单勾表示已发送
        return Icon(Icons.check, size: 14, color: colors.textTertiary);
      case MessageDisplayStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: colors.textTertiary);
      case MessageDisplayStatus.read:
        // 蓝色双勾表示已读
        return Icon(Icons.done_all, size: 14, color: colors.info);
      case MessageDisplayStatus.failed:
        // 错误图标在气泡左侧显示
        return const SizedBox.shrink();
    }
  }

  /// 格式化时间
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
