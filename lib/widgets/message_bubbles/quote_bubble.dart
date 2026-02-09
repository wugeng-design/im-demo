import 'package:flutter/material.dart';

import '../../sdk/models/message.dart';
import '../../theme/im_design_tokens.dart';

/// 引用消息气泡（显示被回复的消息）
class QuoteBubble extends StatelessWidget {
  const QuoteBubble({
    super.key,
    required this.replyInfo,
    required this.isSentByMe,
    this.onTap,
  });

  /// 回复信息
  final ReplyInfo replyInfo;

  /// 是否是自己发送的消息
  final bool isSentByMe;

  /// 点击回调（用于跳转到原消息）
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    // 根据发送者决定颜色
    final backgroundColor = isSentByMe
        ? colors.primary.withValues(alpha: 0.15)
        : colors.surfaceVariant;
    final borderColor = isSentByMe
        ? colors.primary.withValues(alpha: 0.5)
        : colors.textTertiary.withValues(alpha: 0.5);
    final senderColor = colors.primary;
    final bodyColor = isSentByMe ? Colors.black54 : colors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: borderColor,
              width: 3,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 发送者名称
            Text(
              replyInfo.senderName,
              style: TextStyle(
                color: senderColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            // 消息内容
            Text(
              replyInfo.displayBody,
              style: TextStyle(
                color: bodyColor,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
