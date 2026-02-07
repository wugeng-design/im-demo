import 'package:flutter/material.dart';

/// 消息样式常量
class MessageStyles {
  MessageStyles._();

  // ===========================================================================
  // 尺寸常量
  // ===========================================================================

  /// 消息气泡最大宽度
  static const double bubbleMaxWidth = 280.0;

  /// 消息气泡最大宽度比例
  static const double bubbleMaxWidthRatio = 0.75;

  /// 头像尺寸
  static const double avatarSize = 40.0;

  /// 头像与消息间距
  static const double avatarSpacing = 8.0;

  /// 图片消息最大宽度比例
  static const double imageMaxWidthRatio = 0.55;

  /// 图片消息最大高度
  static const double imageMaxHeight = 280.0;

  /// 图片消息最小尺寸
  static const double imageMinSize = 100.0;

  // ===========================================================================
  // BorderRadius 常量
  // ===========================================================================

  /// 消息气泡圆角 (12px)
  static const bubbleRadius = BorderRadius.all(Radius.circular(12));

  /// 发送消息气泡圆角 (右上角尖锐)
  static const bubbleRadiusSent = BorderRadius.only(
    topLeft: Radius.circular(12),
    topRight: Radius.zero,
    bottomLeft: Radius.circular(12),
    bottomRight: Radius.circular(12),
  );

  /// 接收消息气泡圆角 (左上角尖锐)
  static const bubbleRadiusReceived = BorderRadius.only(
    topLeft: Radius.zero,
    topRight: Radius.circular(12),
    bottomLeft: Radius.circular(12),
    bottomRight: Radius.circular(12),
  );

  /// 小圆角 (4px)
  static const smallRadius = BorderRadius.all(Radius.circular(4));

  // ===========================================================================
  // EdgeInsets 常量
  // ===========================================================================

  /// 消息气泡内边距
  static const bubblePadding = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

  /// 时间戳区域内边距
  static const timePadding = EdgeInsets.only(left: 12, right: 12, bottom: 8);

  /// 状态指示器内边距
  static const statusIndicatorPadding = EdgeInsets.all(2);

  // ===========================================================================
  // BoxConstraints 常量
  // ===========================================================================

  /// 消息气泡约束
  static const bubbleConstraints = BoxConstraints(maxWidth: bubbleMaxWidth);

  // ===========================================================================
  // TextStyle 获取方法
  // ===========================================================================

  /// 消息正文样式
  static TextStyle bodyText(Color color) {
    return TextStyle(
      fontSize: 16,
      color: color,
      height: 1.5,
    );
  }

  /// 时间戳样式
  static TextStyle timeText(Color color) {
    return TextStyle(
      fontSize: 11,
      color: color,
    );
  }

  /// 发送者名称样式
  static TextStyle senderName(Color color) {
    return TextStyle(
      fontSize: 12,
      color: color,
      fontWeight: FontWeight.w500,
    );
  }

  /// 系统消息样式
  static TextStyle systemText(Color color) {
    return TextStyle(
      fontSize: 12,
      color: color,
    );
  }

  // ===========================================================================
  // BoxDecoration 获取方法
  // ===========================================================================

  /// 消息气泡装饰
  static BoxDecoration bubble(Color color, {BorderRadius? radius}) {
    return BoxDecoration(
      color: color,
      borderRadius: radius ?? bubbleRadius,
    );
  }

  /// 状态指示器装饰
  static BoxDecoration statusIndicator(Color color) {
    return BoxDecoration(
      color: color,
      borderRadius: smallRadius,
    );
  }
}
