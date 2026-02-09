import 'package:flutter/material.dart';

import '../../theme/im_design_tokens.dart';
import '../../theme/message_styles.dart';

/// 已撤回消息气泡
///
/// 显示撤回提示信息，如 "你撤回了一条消息" 或 "对方撤回了一条消息"
///
/// 设计说明（同步自 Light-1-Client）：
/// - 撤回消息显示为居中的系统消息样式，不显示头像和昵称
/// - 显示格式："XXX撤回了一条消息"
/// - 自己撤回的消息可点击"重新编辑"
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

  /// 重新编辑回调（仅自己撤回的消息可用）
  final VoidCallback? onReEdit;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    final retractText = _buildMessage();

    // 显示为居中的系统消息样式（同步自 Light-1-Client）
    return Container(
      padding: MessageStyles.systemMessagePadding,
      alignment: Alignment.center,
      child: Container(
        padding: MessageStyles.systemMessageInnerPadding,
        decoration: MessageStyles.systemMessage(
          colors.surfaceVariant.withValues(alpha: 0.5),
        ),
        child: isSentByMe && onReEdit != null
            ? _buildWithReEdit(colors, retractText)
            : _buildTextOnly(colors, retractText),
      ),
    );
  }

  /// 构建纯文本样式（不可重新编辑）
  Widget _buildTextOnly(ImColorScheme colors, String text) {
    return Text(
      text,
      style: MessageStyles.systemText(colors.textSecondary),
    );
  }

  /// 构建带"重新编辑"的样式
  Widget _buildWithReEdit(ImColorScheme colors, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: MessageStyles.systemText(colors.textSecondary),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onReEdit,
          child: const Text(
            '重新编辑',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF3A548C),
            ),
          ),
        ),
      ],
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
