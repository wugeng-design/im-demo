import 'package:flutter/material.dart';

import '../theme/im_design_tokens.dart';

/// 消息发送失败指示器
///
/// 微信风格的红色感叹号，点击可重试
/// 同步自 Light-1-Client
class MessageFailedIndicator extends StatelessWidget {
  const MessageFailedIndicator({
    super.key,
    required this.onRetry,
    this.errorMessage,
    this.size = 20.0,
  });

  /// 重试回调
  final VoidCallback onRetry;

  /// 错误信息（显示在 tooltip 中）
  final String? errorMessage;

  /// 图标大小
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    final indicator = GestureDetector(
      onTap: onRetry,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colors.error,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.priority_high,
          size: size * 0.7,
          color: Colors.white,
        ),
      ),
    );

    // 如果有错误信息，包装 Tooltip
    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return Tooltip(
        message: '$errorMessage\n点击重试',
        child: indicator,
      );
    }

    return Tooltip(
      message: '发送失败，点击重试',
      child: indicator,
    );
  }
}

/// 消息状态组件
///
/// 根据消息状态显示不同的指示器（同步自 Light-1-Client）：
/// - sending: 加载中动画
/// - sent: 单勾 ✓
/// - delivered: 双勾 ✓✓
/// - read: 蓝色双勾 ✓✓
/// - failed: 红色感叹号（可点击重试）
/// - pendingSend: 橙色暂停图标（等待网络）
class MessageStatusWidget extends StatelessWidget {
  const MessageStatusWidget({
    super.key,
    required this.status,
    this.onRetry,
    this.errorMessage,
    this.size = 16.0,
  });

  /// 消息状态
  final MessageStatusType status;

  /// 重试回调（仅 failed 状态使用）
  final VoidCallback? onRetry;

  /// 错误信息
  final String? errorMessage;

  /// 图标大小
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    switch (status) {
      case MessageStatusType.sending:
        return SizedBox(
          width: size,
          height: size,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            valueColor: AlwaysStoppedAnimation(colors.textTertiary),
          ),
        );

      case MessageStatusType.sent:
        return Icon(
          Icons.check,
          size: size,
          color: colors.textTertiary,
        );

      case MessageStatusType.delivered:
        return Icon(
          Icons.done_all,
          size: size,
          color: colors.textTertiary,
        );

      case MessageStatusType.read:
        return Icon(
          Icons.done_all,
          size: size,
          color: colors.info, // 蓝色表示已读
        );

      case MessageStatusType.failed:
        return MessageFailedIndicator(
          onRetry: onRetry ?? () {},
          errorMessage: errorMessage,
          size: size,
        );

      case MessageStatusType.pendingSend:
        // 待发送状态 - 显示暂停图标
        // 表示：上传已完成，等待网络恢复后自动发送
        return Tooltip(
          message: '等待网络连接后自动发送',
          child: Icon(
            Icons.pause_circle_outline,
            size: size,
            color: colors.warning, // 橙色表示等待
          ),
        );
    }
  }
}

/// 消息状态类型
enum MessageStatusType {
  sending,
  sent,
  delivered,
  read,
  failed,
  /// 待发送（媒体上传完成，等待连接恢复）
  pendingSend,
}

/// 从字符串转换
extension MessageStatusTypeExtension on MessageStatusType {
  static MessageStatusType fromString(String value) {
    switch (value) {
      case 'sending':
        return MessageStatusType.sending;
      case 'sent':
        return MessageStatusType.sent;
      case 'delivered':
        return MessageStatusType.delivered;
      case 'read':
        return MessageStatusType.read;
      case 'failed':
        return MessageStatusType.failed;
      case 'pendingSend':
        return MessageStatusType.pendingSend;
      default:
        return MessageStatusType.sent;
    }
  }
}
