/// 消息转发选择器
///
/// 底部弹出的会话选择器，用于选择转发目标
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/im_provider.dart';
import '../sdk/models/conversation.dart';
import '../theme/im_design_tokens.dart';
import 'im_avatar.dart';

/// 转发消息选择器
///
/// 使用与会话列表相同的数据源，保持一致性。
/// 支持排除当前会话（避免转发给自己）。
///
/// 使用方式：
/// ```dart
/// final selectedConversation = await ForwardMessageSheet.show(
///   context: context,
///   ref: ref,
///   messagePreview: '消息内容预览',
///   excludeConversationId: currentConversationId,  // 可选：排除当前会话
/// );
/// ```
class ForwardMessageSheet extends ConsumerStatefulWidget {
  const ForwardMessageSheet({
    super.key,
    required this.messagePreview,
    this.excludeConversationId,
  });

  /// 消息预览内容
  final String messagePreview;

  /// 要排除的会话 ID（通常是当前会话，避免转发给自己）
  final String? excludeConversationId;

  /// 显示转发选择器
  ///
  /// 返回选中的会话 [Conversation]，null 表示取消
  static Future<Conversation?> show({
    required BuildContext context,
    required WidgetRef ref,
    required String messagePreview,
    String? excludeConversationId,
  }) async {
    return showModalBottomSheet<Conversation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ForwardMessageSheet(
        messagePreview: messagePreview,
        excludeConversationId: excludeConversationId,
      ),
    );
  }

  @override
  ConsumerState<ForwardMessageSheet> createState() =>
      _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends ConsumerState<ForwardMessageSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);
    final conversations = ref.watch(conversationsProvider);

    // 获取底部安全区域高度，确保不被导航栏遮挡
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75 + bottomPadding,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // 标题栏
          _buildTitleBar(colors),
          // 搜索框
          _buildSearchBar(colors),
          // 消息预览
          _buildMessagePreview(colors),
          Divider(height: 1, color: colors.divider),
          // 会话列表
          Expanded(
            child: _buildConversationList(colors, conversations, bottomPadding),
          ),
        ],
      ),
    );
  }

  /// 构建标题栏
  Widget _buildTitleBar(ImColorScheme colors) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '转发到',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close,
                size: 18,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建搜索框
  Widget _buildSearchBar(ImColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索会话',
          hintStyle: TextStyle(color: colors.textTertiary),
          prefixIcon: Icon(Icons.search, color: colors.textTertiary),
          filled: true,
          fillColor: colors.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  /// 构建消息预览
  Widget _buildMessagePreview(ImColorScheme colors) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.chat_bubble_outline, size: 16, color: colors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.messagePreview,
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建会话列表
  Widget _buildConversationList(
    ImColorScheme colors,
    List<Conversation> conversations,
    double bottomPadding,
  ) {
    // 过滤会话
    final filtered = _filterConversations(conversations);

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          '暂无会话',
          style: TextStyle(color: colors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(bottom: bottomPadding),
      itemCount: filtered.length,
      itemBuilder: (context, index) => _ConversationTile(
        conversation: filtered[index],
        colors: colors,
        onTap: () => _onConversationSelected(filtered[index]),
      ),
    );
  }

  /// 过滤会话列表（排除当前会话 + 搜索）
  List<Conversation> _filterConversations(List<Conversation> conversations) {
    var filtered = conversations.toList();

    // 排除当前会话
    if (widget.excludeConversationId != null) {
      filtered = filtered
          .where((c) => c.id != widget.excludeConversationId)
          .toList();
    }

    // 搜索过滤（通过名称搜索）
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((c) {
        final name = c.name.toLowerCase();
        return name.contains(query);
      }).toList();
    }

    return filtered;
  }

  /// 选中会话
  void _onConversationSelected(Conversation conversation) {
    Navigator.pop(context, conversation);
  }
}

/// 会话列表项
class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.conversation,
    required this.colors,
    required this.onTap,
  });

  final Conversation conversation;
  final ImColorScheme colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ImAvatar(
        userId: conversation.id,
        name: conversation.name,
        avatarUrl: conversation.avatar,
        size: 44,
      ),
      title: Text(
        conversation.name,
        style: TextStyle(
          fontSize: 16,
          color: colors.textPrimary,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: conversation.isGroup
          ? Text(
              '群聊',
              style: TextStyle(
                fontSize: 13,
                color: colors.textSecondary,
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}
