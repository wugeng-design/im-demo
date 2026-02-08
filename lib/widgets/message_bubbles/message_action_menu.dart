import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../sdk/models/message.dart';
import '../../theme/im_design_tokens.dart';

/// 消息操作类型
enum MessageMenuAction {
  /// 复制
  copy,

  /// 重试发送
  retry,

  /// 删除（本地）
  delete,

  /// 撤回
  recall,

  /// 编辑
  edit,

  /// 转发
  forward,

  /// 回复/引用
  reply,

  /// 多选
  multiSelect,
}

/// 消息操作菜单项
class _MenuItem {
  final MessageMenuAction action;
  final IconData icon;
  final String label;

  const _MenuItem({
    required this.action,
    required this.icon,
    required this.label,
  });
}

/// 消息长按菜单
///
/// 微信风格的浮层菜单，显示可用的消息操作
class MessageLongPressMenu {
  /// 撤回时限（2分钟）
  static const Duration recallTimeLimit = Duration(minutes: 2);

  /// 显示消息操作菜单
  ///
  /// 返回用户选择的操作，或 null（如果取消）
  static Future<MessageMenuAction?> show({
    required BuildContext context,
    required Message message,
    required Offset position,
  }) async {
    // 构建可用的菜单项
    final items = _buildMenuItems(message);
    if (items.isEmpty) return null;

    // 震动反馈
    HapticFeedback.mediumImpact();

    return showDialog<MessageMenuAction>(
      context: context,
      barrierColor: Colors.black26,
      builder: (context) => _MenuOverlay(
        items: items,
        position: position,
      ),
    );
  }

  /// 根据消息状态构建可用的菜单项
  static List<_MenuItem> _buildMenuItems(Message message) {
    final items = <_MenuItem>[];
    final isFailed = message.status == 'failed';
    final isSending = message.status == 'sending';
    final isTextMessage = message.messageType == MessageType.text;
    final canRecall = _canRecallMessage(message);

    // 发送失败 -> 重试
    if (isFailed) {
      items.add(const _MenuItem(
        action: MessageMenuAction.retry,
        icon: Icons.refresh,
        label: '重试',
      ));
    }

    // 文本消息 -> 复制
    if (isTextMessage && !isSending && !isFailed) {
      items.add(const _MenuItem(
        action: MessageMenuAction.copy,
        icon: Icons.copy,
        label: '复制',
      ));
    }

    // 回复（非失败、非发送中）
    if (!isFailed && !isSending) {
      items.add(const _MenuItem(
        action: MessageMenuAction.reply,
        icon: Icons.reply,
        label: '回复',
      ));
    }

    // 转发（非失败、非发送中）
    if (!isFailed && !isSending) {
      items.add(const _MenuItem(
        action: MessageMenuAction.forward,
        icon: Icons.forward,
        label: '转发',
      ));
    }

    // 自己发送的文本消息 -> 编辑（2分钟内）
    if (message.isMe && isTextMessage && canRecall && !isFailed && !isSending) {
      items.add(const _MenuItem(
        action: MessageMenuAction.edit,
        icon: Icons.edit,
        label: '编辑',
      ));
    }

    // 自己发送的消息 -> 撤回（2分钟内）
    if (message.isMe && canRecall && !isFailed && !isSending) {
      items.add(const _MenuItem(
        action: MessageMenuAction.recall,
        icon: Icons.undo,
        label: '撤回',
      ));
    }

    // 多选
    if (!isSending && !isFailed) {
      items.add(const _MenuItem(
        action: MessageMenuAction.multiSelect,
        icon: Icons.checklist,
        label: '多选',
      ));
    }

    // 删除（本地）
    items.add(const _MenuItem(
      action: MessageMenuAction.delete,
      icon: Icons.delete_outline,
      label: '删除',
    ));

    return items;
  }

  /// 检查消息是否可以撤回（2分钟内）
  static bool _canRecallMessage(Message message) {
    if (!message.isMe) return false;
    final elapsed = DateTime.now().difference(message.timestamp);
    return elapsed <= recallTimeLimit;
  }
}

/// 菜单浮层
class _MenuOverlay extends StatelessWidget {
  final List<_MenuItem> items;
  final Offset position;

  const _MenuOverlay({
    required this.items,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);
    final screenSize = MediaQuery.of(context).size;
    final menuWidth = _calculateMenuWidth();

    // 计算菜单位置（避免超出屏幕）
    double left = position.dx - menuWidth / 2;
    double top = position.dy - 60; // 默认显示在点击位置上方

    // 水平边界检查
    if (left < 12) left = 12;
    if (left + menuWidth > screenSize.width - 12) {
      left = screenSize.width - menuWidth - 12;
    }

    // 垂直边界检查（如果上方空间不够，显示在下方）
    if (top < 80) {
      top = position.dy + 20;
    }

    return Stack(
      children: [
        // 背景（点击关闭）
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(color: Colors.transparent),
          ),
        ),
        // 菜单卡片
        Positioned(
          left: left,
          top: top,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.8, end: 1.0),
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: scale.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: _buildMenuCard(context, colors),
          ),
        ),
      ],
    );
  }

  double _calculateMenuWidth() {
    // 每个项目 52px，最多一行 5 个
    final itemsPerRow = items.length > 5 ? 5 : items.length;
    return itemsPerRow * 52.0 + 16; // 加上 padding
  }

  Widget _buildMenuCard(BuildContext context, ImColorScheme colors) {
    return Material(
      color: const Color(0xFF2C2C2C),
      borderRadius: BorderRadius.circular(8),
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.2),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Wrap(
          spacing: 4,
          runSpacing: 4,
          children: items.map((item) => _buildMenuItem(context, item)).toList(),
        ),
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, _MenuItem item) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(item.action),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 48,
        height: 52,
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
