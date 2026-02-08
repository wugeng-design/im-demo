import 'package:flutter/material.dart';

import '../../theme/im_design_tokens.dart';

/// 已撤回消息气泡
///
/// 显示撤回提示信息，如 "你撤回了一条消息" 或 "对方撤回了一条消息"
class RecalledMessageBubble extends StatelessWidget {
  const RecalledMessageBubble({
    super.key,
    required this.isSentByMe,
    this.senderName,
    this.onReEdit,
  });

  /// 是否是自己撤回的消息
  final bool isSentByMe;

  /// 发送者名称（非自己撤回时显示）
  final String? senderName;

  /// 重新编辑回调（仅自己撤回的消息可用，2分钟内）
  final VoidCallback? onReEdit;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceVariant.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 14,
                color: colors.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                _buildMessage(),
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
              if (isSentByMe && onReEdit != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onReEdit,
                  child: Text(
                    '重新编辑',
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _buildMessage() {
    if (isSentByMe) {
      return '你撤回了一条消息';
    }
    if (senderName != null && senderName!.isNotEmpty) {
      return '"$senderName" 撤回了一条消息';
    }
    return '对方撤回了一条消息';
  }
}
