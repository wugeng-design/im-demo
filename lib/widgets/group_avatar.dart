/// 群头像组件
///
/// 微信风格九宫格布局：
/// - 1人: 居中显示
/// - 2人: 左右排列
/// - 3人: 上1下2
/// - 4人: 2x2
/// - 5人: 上2下3
/// - 6人: 2x3
/// - 7人: 上1中3下3
/// - 8人: 上2中3下3
/// - 9人: 3x3
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 群成员头像信息
class GroupMemberAvatar {
  const GroupMemberAvatar({
    required this.memberId,
    this.avatarUrl,
    this.name,
  });

  final String memberId;
  final String? avatarUrl;
  final String? name;
}

/// 群头像组件（微信风格九宫格）
class GroupAvatar extends StatelessWidget {
  const GroupAvatar({
    super.key,
    required this.members,
    this.size = 48,
    this.gap = 2,
    this.padding = 2,
    this.backgroundColor = const Color(0xFFE5E5E5),
    this.borderRadius = 8,
  });

  /// 群成员列表（最多取前9个）
  final List<GroupMemberAvatar> members;

  /// 头像大小
  final double size;

  /// 成员头像间隔
  final double gap;

  /// 边距
  final double padding;

  /// 背景颜色
  final Color backgroundColor;

  /// 圆角半径
  final double borderRadius;

  /// 预定义的占位符颜色
  static const List<Color> _placeholderColors = [
    Color(0xFF5B8FF9), // 蓝色
    Color(0xFF5AD8A6), // 青色
    Color(0xFF5D7092), // 灰蓝
    Color(0xFFF6BD16), // 黄色
    Color(0xFFE86452), // 红色
    Color(0xFF6DC8EC), // 浅蓝
    Color(0xFF945FB9), // 紫色
    Color(0xFFFF9845), // 橙色
    Color(0xFF1E9493), // 深青
    Color(0xFF6F5EF9), // 深紫
  ];

  @override
  Widget build(BuildContext context) {
    final effectiveMembers = members.take(9).toList();

    if (effectiveMembers.isEmpty) {
      return _buildEmptyAvatar();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildGrid(effectiveMembers),
    );
  }

  /// 构建空头像
  Widget _buildEmptyAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.group,
        size: size * 0.5,
        color: Colors.grey,
      ),
    );
  }

  /// 构建九宫格布局
  Widget _buildGrid(List<GroupMemberAvatar> effectiveMembers) {
    final count = effectiveMembers.length;
    final availableSize = size - padding * 2;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: _buildLayout(effectiveMembers, count, availableSize),
    );
  }

  Widget _buildLayout(
    List<GroupMemberAvatar> members,
    int count,
    double availableSize,
  ) {
    switch (count) {
      case 1:
        // 单人：居中，占 60%
        final memberSize = availableSize * 0.6;
        return Center(
          child: _buildMemberAvatar(members[0], memberSize),
        );

      case 2:
        // 两人：左右排列
        final memberSize = (availableSize - gap) / 2;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMemberAvatar(members[0], memberSize),
            SizedBox(width: gap),
            _buildMemberAvatar(members[1], memberSize),
          ],
        );

      case 3:
        // 三人：上1下2
        final memberSize = (availableSize - gap) / 2;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMemberAvatar(members[0], memberSize),
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMemberAvatar(members[1], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[2], memberSize),
              ],
            ),
          ],
        );

      case 4:
        // 四人：2x2
        final memberSize = (availableSize - gap) / 2;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMemberAvatar(members[0], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[1], memberSize),
              ],
            ),
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMemberAvatar(members[2], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[3], memberSize),
              ],
            ),
          ],
        );

      case 5:
        // 五人：上2下3
        final smallSize = (availableSize - gap * 2) / 3;
        final largeSize = (availableSize - gap) / 2;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMemberAvatar(members[0], largeSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[1], largeSize),
              ],
            ),
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMemberAvatar(members[2], smallSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[3], smallSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[4], smallSize),
              ],
            ),
          ],
        );

      case 6:
        // 六人：2x3
        final memberSize = (availableSize - gap * 2) / 3;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMemberAvatar(members[0], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[1], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[2], memberSize),
              ],
            ),
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMemberAvatar(members[3], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[4], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[5], memberSize),
              ],
            ),
          ],
        );

      case 7:
        // 七人：上1中3下3
        final memberSize = (availableSize - gap * 2) / 3;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildMemberAvatar(members[0], memberSize),
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMemberAvatar(members[1], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[2], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[3], memberSize),
              ],
            ),
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMemberAvatar(members[4], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[5], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[6], memberSize),
              ],
            ),
          ],
        );

      case 8:
        // 八人：上2中3下3
        final memberSize = (availableSize - gap * 2) / 3;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMemberAvatar(members[0], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[1], memberSize),
              ],
            ),
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMemberAvatar(members[2], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[3], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[4], memberSize),
              ],
            ),
            SizedBox(height: gap),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildMemberAvatar(members[5], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[6], memberSize),
                SizedBox(width: gap),
                _buildMemberAvatar(members[7], memberSize),
              ],
            ),
          ],
        );

      default:
        // 九人：3x3
        final memberSize = (availableSize - gap * 2) / 3;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (int row = 0; row < 3; row++) ...[
              if (row > 0) SizedBox(height: gap),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int col = 0; col < 3; col++) ...[
                    if (col > 0) SizedBox(width: gap),
                    _buildMemberAvatar(members[row * 3 + col], memberSize),
                  ],
                ],
              ),
            ],
          ],
        );
    }
  }

  /// 构建单个成员头像
  Widget _buildMemberAvatar(GroupMemberAvatar member, double memberSize) {
    return ClipOval(
      child: SizedBox(
        width: memberSize,
        height: memberSize,
        child: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: member.avatarUrl!,
                width: memberSize,
                height: memberSize,
                fit: BoxFit.cover,
                placeholder: (context, url) => _buildPlaceholder(member, memberSize),
                errorWidget: (context, url, error) => _buildPlaceholder(member, memberSize),
              )
            : _buildPlaceholder(member, memberSize),
      ),
    );
  }

  /// 构建占位符
  Widget _buildPlaceholder(GroupMemberAvatar member, double memberSize) {
    final text = _getPlaceholderText(member.name);
    final color = _getPlaceholderColor(member.memberId);

    return Container(
      width: memberSize,
      height: memberSize,
      color: color,
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white,
          fontSize: memberSize * 0.4,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 获取占位符文本
  String _getPlaceholderText(String? name) {
    if (name == null || name.isEmpty) return '?';
    return name.characters.first.toUpperCase();
  }

  /// 获取占位符颜色
  Color _getPlaceholderColor(String memberId) {
    final hash = memberId.hashCode.abs();
    return _placeholderColors[hash % _placeholderColors.length];
  }
}
