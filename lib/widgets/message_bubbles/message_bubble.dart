import 'package:flutter/material.dart';

import '../../theme/im_design_tokens.dart';
import '../../theme/message_styles.dart';

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
    this.senderName,
    this.showSenderName = false,
    this.onLongPress,
    this.onTap,
  });

  /// 消息内容
  final String body;

  /// 时间戳
  final DateTime timestamp;

  /// 是否是自己发送的
  final bool isSentByMe;

  /// 消息状态
  final MessageDisplayStatus? status;

  /// 发送者名称（群聊时显示）
  final String? senderName;

  /// 是否显示发送者名称
  final bool showSenderName;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 点击回调
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 发送失败图标（自己发送的消息，显示在左侧）
          if (isSentByMe && status == MessageDisplayStatus.failed)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.error_outline,
                size: 18,
                color: colors.error,
              ),
            ),
          // 消息气泡
          GestureDetector(
            onLongPress: onLongPress,
            onTap: onTap,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
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
                  // 消息内容
                  Text(
                    body,
                    style: TextStyle(
                      color: isSentByMe ? Colors.black87 : colors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // 时间和状态
                  _buildFooter(colors),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建底部（时间 + 状态）
  Widget _buildFooter(ImColorScheme colors) {
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
        if (isSentByMe && status != null) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(colors),
        ],
      ],
    );
  }

  /// 构建消息状态图标
  Widget _buildStatusIcon(ImColorScheme colors) {
    switch (status!) {
      case MessageDisplayStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.black45,
          ),
        );
      case MessageDisplayStatus.sent:
        // 发送成功不显示对勾
        return const SizedBox.shrink();
      case MessageDisplayStatus.delivered:
        return const Icon(Icons.done_all, size: 14, color: Colors.black45);
      case MessageDisplayStatus.read:
        return Icon(Icons.done_all, size: 14, color: colors.primary);
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
