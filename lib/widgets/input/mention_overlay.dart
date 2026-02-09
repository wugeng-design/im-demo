/// @提及成员选择弹出层
///
/// 功能：
/// - 显示匹配的群成员列表
/// - 处理成员选择交互
/// - 支持键盘上下选择
library;

import 'package:flutter/material.dart';

import '../../theme/im_design_tokens.dart';
import 'mention_models.dart';

/// @提及成员选择弹出层
class MentionOverlay extends StatefulWidget {
  const MentionOverlay({
    super.key,
    required this.members,
    required this.query,
    required this.onMemberSelected,
    this.maxHeight = 200,
  });

  /// 可提及的成员列表
  final List<MentionableMember> members;

  /// 当前查询文本 (@ 后面的内容)
  final String query;

  /// 成员选中回调
  final void Function(MentionableMember member) onMemberSelected;

  /// 最大高度
  final double maxHeight;

  @override
  State<MentionOverlay> createState() => MentionOverlayState();
}

/// MentionOverlay 状态类
///
/// 公开以支持外部通过 GlobalKey 控制选择
class MentionOverlayState extends State<MentionOverlay> {
  /// 当前选中的索引（0 为默认选中第一个）
  int _selectedIndex = 0;

  /// 滚动控制器
  final ScrollController _scrollController = ScrollController();

  /// 获取过滤后的成员列表
  List<MentionableMember> get filteredMembers => _filterMembers();

  @override
  void didUpdateWidget(covariant MentionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 当 query 变化时，重置选中索引
    if (oldWidget.query != widget.query) {
      setState(() {
        _selectedIndex = 0;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 向上移动选择
  void moveSelectionUp() {
    final members = filteredMembers;
    if (members.isEmpty) return;

    setState(() {
      _selectedIndex = (_selectedIndex - 1).clamp(0, members.length - 1);
    });
    _ensureVisible();
  }

  /// 向下移动选择
  void moveSelectionDown() {
    final members = filteredMembers;
    if (members.isEmpty) return;

    setState(() {
      _selectedIndex = (_selectedIndex + 1).clamp(0, members.length - 1);
    });
    _ensureVisible();
  }

  /// 确认当前选择
  void confirmSelection() {
    final members = filteredMembers;
    if (members.isEmpty ||
        _selectedIndex < 0 ||
        _selectedIndex >= members.length) {
      return;
    }
    widget.onMemberSelected(members[_selectedIndex]);
  }

  /// 确保选中项可见
  void _ensureVisible() {
    // 每个项目大约 52 像素高度（8 + 36 + 8 padding）
    const itemHeight = 52.0;
    final targetOffset = _selectedIndex * itemHeight;

    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset.clamp(0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    // 过滤匹配的成员
    final members = filteredMembers;

    if (members.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              '选择成员',
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // 成员列表
          Flexible(
            child: ListView.builder(
              controller: _scrollController,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: members.length,
              itemBuilder: (context, index) {
                return _buildMemberTile(
                  context,
                  members[index],
                  colors,
                  isSelected: index == _selectedIndex,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 过滤匹配的成员
  ///
  /// 只通过 nickname 搜索，不通过 bareJid 搜索
  /// 避免通过试探暴露内部 bareJid 信息
  List<MentionableMember> _filterMembers() {
    if (widget.query.isEmpty) {
      return widget.members;
    }

    final lowerQuery = widget.query.toLowerCase();
    return widget.members.where((m) {
      return m.nickname.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// 构建成员列表项
  Widget _buildMemberTile(
    BuildContext context,
    MentionableMember member,
    ImColorScheme colors, {
    bool isSelected = false,
  }) {
    return InkWell(
      onTap: () => widget.onMemberSelected(member),
      child: Container(
        color: isSelected ? colors.primary.withValues(alpha: 0.1) : null,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // 头像 - 使用简单的 CircleAvatar
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.primary.withValues(alpha: 0.2),
              backgroundImage: member.avatarUrl != null
                  ? NetworkImage(member.avatarUrl!)
                  : null,
              child: member.avatarUrl == null
                  ? Text(
                      member.nickname.isNotEmpty
                          ? member.nickname[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: colors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            // 昵称
            Expanded(
              child: Text(
                member.nickname,
                style: TextStyle(
                  fontSize: 15,
                  color: isSelected ? colors.primary : colors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
