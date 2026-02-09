/// 已编辑消息气泡组件
///
/// 显示消息内容，底部带"已编辑"标签
library;

import 'package:flutter/material.dart';

import '../../theme/im_design_tokens.dart';
import '../../theme/message_styles.dart';

/// 已编辑消息气泡
///
/// 专门用于显示已编辑的消息，底部自动带"已编辑"标签
class EditedMessageBubble extends StatelessWidget {
  const EditedMessageBubble({
    super.key,
    required this.text,
    required this.timestamp,
    required this.isSentByMe,
    this.status,
    this.onLongPress,
    this.onRetry,
  });

  /// 消息文本
  final String text;

  /// 时间戳
  final DateTime timestamp;

  /// 是否是自己发送的
  final bool isSentByMe;

  /// 消息状态 (sending, sent, failed)
  final String? status;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 重试回调（消息发送失败时）
  final VoidCallback? onRetry;

  bool get _isFailed => status == 'failed';

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);
    final textColor = isSentByMe ? Colors.black87 : colors.textPrimary;
    final bubbleColor = isSentByMe
        ? colors.messageBubbleSent
        : colors.messageBubbleReceived;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Container(
        constraints: MessageStyles.bubbleConstraints,
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
            // 消息内容
            Text(
              text,
              style: MessageStyles.bodyText(textColor),
            ),
            // 时间和状态（微信风格：不显示）
            // const SizedBox(height: 4),
            // _buildTimeAndStatus(colors),
          ],
        ),
      ),
    );
  }

  /// 构建状态行
  Widget _buildTimeAndStatus(ImColorScheme colors) {
    final secondaryColor = isSentByMe ? Colors.black45 : colors.textTertiary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 已编辑标记
        Text(
          '已编辑',
          style: TextStyle(
            color: secondaryColor,
            fontSize: 10,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 4),
        // 时间
        Text(
          _formatTime(timestamp),
          style: TextStyle(
            color: secondaryColor,
            fontSize: 11,
          ),
        ),
        // 状态图标
        if (isSentByMe) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(colors),
        ],
      ],
    );
  }

  Widget _buildStatusIcon(ImColorScheme colors) {
    if (_isFailed) {
      return GestureDetector(
        onTap: onRetry,
        child: Icon(
          Icons.error_outline,
          size: 14,
          color: colors.error,
        ),
      );
    }

    if (status == 'sending') {
      return const SizedBox(
        width: 12,
        height: 12,
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Colors.black45,
        ),
      );
    }

    // 发送成功不显示图标
    return const SizedBox.shrink();
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
