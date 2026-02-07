import 'package:flutter/material.dart';

import '../theme/im_design_tokens.dart';

/// IM 头像组件
///
/// 功能:
/// - 显示用户/群组头像
/// - 支持占位符 (用户名首字母 + 固定背景色)
/// - 圆形头像
class ImAvatar extends StatelessWidget {
  const ImAvatar({
    super.key,
    required this.userId,
    this.avatarUrl,
    this.name,
    this.size,
  });

  /// 用户 ID（用于生成占位符颜色）
  final String userId;

  /// 头像URL（null时显示占位符）
  final String? avatarUrl;

  /// 用户名（用于占位符首字母）
  final String? name;

  /// 尺寸（null时使用 small）
  final double? size;

  /// 小尺寸 - 用于消息气泡
  const ImAvatar.small({
    super.key,
    required this.userId,
    this.avatarUrl,
    this.name,
  }) : size = ImDesignTokens.avatarSizeSmall;

  /// 中尺寸 - 用于会话列表
  const ImAvatar.medium({
    super.key,
    required this.userId,
    this.avatarUrl,
    this.name,
  }) : size = ImDesignTokens.avatarSizeMedium;

  /// 大尺寸 - 用于个人资料
  const ImAvatar.large({
    super.key,
    required this.userId,
    this.avatarUrl,
    this.name,
  }) : size = ImDesignTokens.avatarSizeLarge;

  @override
  Widget build(BuildContext context) {
    final avatarSize = size ?? ImDesignTokens.avatarSizeSmall;

    return SizedBox(
      width: avatarSize,
      height: avatarSize,
      child: ClipOval(
        child: _buildAvatarContent(avatarSize),
      ),
    );
  }

  /// 构建头像内容
  Widget _buildAvatarContent(double avatarSize) {
    // 有头像 URL 时尝试加载网络图片
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return Image.network(
        avatarUrl!,
        width: avatarSize,
        height: avatarSize,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            _buildPlaceholder(avatarSize),
        loadingBuilder: (_, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder(avatarSize);
        },
      );
    }

    // 否则显示占位符
    return _buildPlaceholder(avatarSize);
  }

  /// 构建占位符（首字母 + 背景色）
  Widget _buildPlaceholder(double avatarSize) {
    final placeholderText = _getPlaceholderText();
    final backgroundColor = _getPlaceholderColor();

    return Container(
      width: avatarSize,
      height: avatarSize,
      color: backgroundColor,
      alignment: Alignment.center,
      child: Text(
        placeholderText,
        style: TextStyle(
          color: Colors.white,
          fontSize: avatarSize * 0.4,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// 获取占位符文本（首字母）
  String _getPlaceholderText() {
    if (name == null || name!.isEmpty) return '?';
    return name!.characters.first.toUpperCase();
  }

  /// 根据 userId 生成固定的占位符背景色
  Color _getPlaceholderColor() {
    // 预定义颜色列表（柔和的颜色）
    const colors = [
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

    // 根据 userId 哈希选择颜色
    final hash = userId.hashCode.abs();
    return colors[hash % colors.length];
  }
}
