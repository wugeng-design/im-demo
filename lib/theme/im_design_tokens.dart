import 'package:flutter/material.dart';

/// IM 模块设计 Token
///
/// 所有颜色、尺寸、间距等设计常量的单一真实来源
/// 支持 Light/Dark 两套主题
class ImDesignTokens {
  ImDesignTokens._();

  // ========== 颜色系统 ==========

  /// 主色（微信绿）
  static const Color primaryColor = Color(0xFF07C160);

  /// Light 主题颜色
  static const ImColorScheme light = ImColorScheme(
    // 主色
    primary: primaryColor,
    onPrimary: Colors.white,

    // 背景色
    background: Color(0xFFF6F7FB),
    surface: Colors.white,
    surfaceVariant: Color(0xFFF7F7F7),

    // 文本色
    textPrimary: Color(0xFF191919),
    textSecondary: Color(0xFF888888),
    textTertiary: Color(0xFFB3B3B3),
    textDisabled: Color(0xFFCCCCCC),

    // 分割线
    divider: Color(0xFFE5E5E5),
    border: Color(0xFFDDDDDD),

    // 功能色
    error: Color(0xFFFA5151),
    success: Color(0xFF07C160),
    warning: Color(0xFFFAAD14),
    info: Color(0xFF1677FF),

    // 消息气泡
    messageBubbleSent: Color(0xFF95EC69),
    messageBubbleReceived: Colors.white,

    // 未读标记
    unreadBadge: Color(0xFFFA5151),
    unreadDot: Color(0xFFFA5151),

    // 在线状态
    statusOnline: Color(0xFF00D26A),
    statusOffline: Color(0xFFAAAAAA),
    statusBusy: Color(0xFFFAAD14),

    // 滑动操作颜色
    slidableMute: Color(0xFFC7C7CC),
    slidableDelete: Color(0xFFFF3B30),
  );

  /// Dark 主题颜色
  static const ImColorScheme dark = ImColorScheme(
    // 主色
    primary: primaryColor,
    onPrimary: Color(0xFF191919),

    // 背景色
    background: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceVariant: Color(0xFF2C2C2E),

    // 文本色
    textPrimary: Color(0xFFE5E5E5),
    textSecondary: Color(0xFF8E8E93),
    textTertiary: Color(0xFF636366),
    textDisabled: Color(0xFF48484A),

    // 分割线
    divider: Color(0xFF38383A),
    border: Color(0xFF48484A),

    // 功能色
    error: Color(0xFFFF453A),
    success: Color(0xFF30D158),
    warning: Color(0xFFFFD60A),
    info: Color(0xFF0A84FF),

    // 消息气泡
    messageBubbleSent: Color(0xFF056D3B),
    messageBubbleReceived: Color(0xFF2C2C2E),

    // 未读标记
    unreadBadge: Color(0xFFFF453A),
    unreadDot: Color(0xFFFF453A),

    // 在线状态
    statusOnline: Color(0xFF32E875),
    statusOffline: Color(0xFF636366),
    statusBusy: Color(0xFFFFD60A),

    // 滑动操作颜色
    slidableMute: Color(0xFF8E8E93),
    slidableDelete: Color(0xFFFF453A),
  );

  // ========== 尺寸系统 ==========

  /// Avatar 尺寸
  static const double avatarSizeSmall = 32.0;
  static const double avatarSizeMedium = 54.0; // 会话列表
  static const double avatarSizeLarge = 60.0; // 用户详情

  /// Badge 尺寸
  static const double badgeSize = 18.0;
  static const double badgeDotSize = 8.0;

  /// 图标尺寸
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 20.0;
  static const double iconSizeLarge = 24.0;

  /// 消息气泡最大宽度（占屏幕比例）
  static const double messageBubbleMaxWidthRatio = 0.7;

  // ========== 间距系统 ==========

  /// 4px 递增间距体系
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;

  /// 页面边距
  static const double pagePadding = 16.0;

  /// 卡片内边距
  static const double cardPadding = 12.0;

  // ========== 圆角系统 ==========

  /// 圆角半径（微信风格：较小圆角）
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 6.0; // 消息气泡
  static const double radiusLarge = 8.0; // 卡片
  static const double radiusRound = 999.0; // 圆形（头像、Badge）

  static const BorderRadius borderRadiusSmall =
      BorderRadius.all(Radius.circular(radiusSmall));
  static const BorderRadius borderRadiusMedium =
      BorderRadius.all(Radius.circular(radiusMedium));
  static const BorderRadius borderRadiusLarge =
      BorderRadius.all(Radius.circular(radiusLarge));
  static const BorderRadius borderRadiusRound =
      BorderRadius.all(Radius.circular(radiusRound));

  // ========== 字体系统 ==========

  /// 字体大小
  static const double fontSizeCaption = 12.0; // 辅助文本（时间）
  static const double fontSizeBody = 14.0; // 正文（消息内容）
  static const double fontSizeSubtitle = 15.0; // 副标题（会话摘要）
  static const double fontSizeTitle = 17.0; // 标题（会话名称）
  static const double fontSizeHeadline = 18.0; // 大标题（页面标题）

  /// 字体粗细
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightBold = FontWeight.w600;

  // ========== 动画时长 ==========

  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 250);
  static const Duration durationSlow = Duration(milliseconds: 350);

  // ========== 阴影 ==========

  /// 卡片阴影
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x0A000000), // 黑色 4% 透明度
      offset: Offset(0, 2),
      blurRadius: 8,
      spreadRadius: 0,
    ),
  ];

  // ========== 辅助方法 ==========

  /// 根据 Brightness 获取对应的颜色方案
  static ImColorScheme colorSchemeOf(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return brightness == Brightness.light ? light : dark;
  }
}

/// IM 颜色方案
///
/// 不可变的颜色定义，支持 Light/Dark 主题
class ImColorScheme {
  const ImColorScheme({
    required this.primary,
    required this.onPrimary,
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDisabled,
    required this.divider,
    required this.border,
    required this.error,
    required this.success,
    required this.warning,
    required this.info,
    required this.messageBubbleSent,
    required this.messageBubbleReceived,
    required this.unreadBadge,
    required this.unreadDot,
    required this.statusOnline,
    required this.statusOffline,
    required this.statusBusy,
    required this.slidableMute,
    required this.slidableDelete,
  });

  // 主色
  final Color primary;
  final Color onPrimary;

  // 背景色
  final Color background;
  final Color surface;
  final Color surfaceVariant;

  // 文本色
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textDisabled;

  // 分割线
  final Color divider;
  final Color border;

  // 功能色
  final Color error;
  final Color success;
  final Color warning;
  final Color info;

  // 消息气泡
  final Color messageBubbleSent;
  final Color messageBubbleReceived;

  // 未读标记
  final Color unreadBadge;
  final Color unreadDot;

  // 在线状态
  final Color statusOnline;
  final Color statusOffline;
  final Color statusBusy;

  // 滑动操作颜色
  final Color slidableMute;
  final Color slidableDelete;
}
