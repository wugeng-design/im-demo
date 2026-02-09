import 'package:flutter/material.dart';

import '../../theme/im_design_tokens.dart';

/// Emoji 面板
///
/// 展示常用 Emoji 列表，点击 Emoji 触发回调
class EmojiPanel extends StatelessWidget {
  const EmojiPanel({
    super.key,
    required this.onEmojiSelected,
    this.height = 250,
  });

  /// Emoji 选中回调
  final void Function(String emoji) onEmojiSelected;

  /// 面板高度
  final double height;

  /// 常用 Emoji 列表
  static const List<String> commonEmojis = [
    // 表情 (20)
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '😊',
    '😇', '🥰', '😍', '🤩', '😘', '😗', '😋', '🤪', '😜', '🙄',
    // 手势 (10)
    '👍', '👎', '👌', '✌️', '🤞', '🤟', '🤘', '👋', '✋', '🙏',
    // 爱心 (8)
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '💔',
    // 动物 (10)
    '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐷',
    // 食物 (10)
    '🍎', '🍊', '🍋', '🍇', '🍓', '🍑', '🍔', '🍕', '🍜', '🍰',
    // 物品 (10)
    '🎁', '🎉', '🎊', '🎈', '💡', '📚', '💻', '📱', '⏰', '🔔',
    // 符号 (6)
    '✅', '❌', '⭐', '🔥', '💯', '❓',
  ];

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.divider, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // 顶部把手
          _buildHandle(colors),
          // Emoji 网格
          Expanded(
            child: _buildEmojiGrid(colors),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle(ImColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: colors.divider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildEmojiGrid(ImColorScheme colors) {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: commonEmojis.length,
      itemBuilder: (context, index) {
        final emoji = commonEmojis[index];
        return _EmojiItem(
          emoji: emoji,
          onTap: () => onEmojiSelected(emoji),
          colors: colors,
        );
      },
    );
  }
}

class _EmojiItem extends StatelessWidget {
  const _EmojiItem({
    required this.emoji,
    required this.onTap,
    required this.colors,
  });

  final String emoji;
  final VoidCallback onTap;
  final ImColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Text(
            emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
