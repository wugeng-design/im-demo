/// 回复消息气泡组件
///
/// 功能：
/// - 显示回复内容 + 引用区域
/// - 引用区域在消息下方（Light-1-Client 样式）
/// - 支持图片/视频缩略图预览
/// - 支持已撤回/已删除状态
/// - 点击引用区域可跳转或预览
library;

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../sdk/models/message.dart';
import '../../theme/im_design_tokens.dart';
import '../../theme/message_styles.dart';

/// 回复消息气泡
///
/// 展示带引用的消息样式，包含被回复消息的预览和实际回复内容
/// Light-1-Client 样式：消息气泡在上方，引用区域在下方
class ReplyMessageBubble extends StatelessWidget {
  const ReplyMessageBubble({
    super.key,
    required this.text,
    required this.replyInfo,
    required this.isSentByMe,
    required this.timestamp,
    this.status,
    this.onReplyTap,
    this.onLongPress,
    this.onRetry,
  });

  /// 回复消息的文本内容
  final String text;

  /// 被回复的消息信息
  final ReplyInfo replyInfo;

  /// 是否是自己发送的
  final bool isSentByMe;

  /// 时间戳
  final DateTime timestamp;

  /// 消息状态
  final String? status;

  /// 点击引用区域的回调
  final VoidCallback? onReplyTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 重试回调
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);
    final maxWidth = MediaQuery.of(context).size.width * 0.75;
    final bubbleColor = isSentByMe
        ? colors.messageBubbleSent
        : colors.messageBubbleReceived;

    // Light-1-Client 样式：消息气泡和引用区域是分离的，引用在下方
    return GestureDetector(
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment:
            isSentByMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 消息气泡
          Container(
            constraints: BoxConstraints(maxWidth: maxWidth),
            padding: const EdgeInsets.all(12),
            decoration: MessageStyles.bubble(
              bubbleColor,
              radius: isSentByMe
                  ? MessageStyles.bubbleRadiusSent
                  : MessageStyles.bubbleRadiusReceived,
            ),
            child: Text(
              text,
              style: MessageStyles.bodyText(
                isSentByMe ? Colors.black87 : colors.textPrimary,
              ),
            ),
          ),
          // 引用区域（在消息下方，间距 4px）
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onReplyTap,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: 28, // Light-1-Client: 引用气泡高度最高 28px
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F2), // Light-1-Client: #F2F2F2
                borderRadius: BorderRadius.circular(4),
              ),
              child: _buildQuotedContent(colors),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建引用内容区域
  Widget _buildQuotedContent(ImColorScheme colors) {
    // 已撤回
    if (replyInfo.isRetracted) {
      return _buildTextQuote(
        senderName: replyInfo.senderName,
        body: '消息已撤回',
        isSpecial: true,
      );
    }

    // 根据消息类型渲染
    switch (replyInfo.messageType) {
      case MessageType.image:
        return _buildImageQuote(colors);
      case MessageType.video:
        return _buildVideoQuote(colors);
      case MessageType.file:
        final fileName = replyInfo.fileName ?? '文件';
        return _buildTextQuote(
          senderName: replyInfo.senderName,
          body: '[文件] $fileName',
        );
      case MessageType.system:
        return _buildTextQuote(
          senderName: replyInfo.senderName,
          body: '[系统消息]',
        );
      case MessageType.text:
        final body = replyInfo.body.length > 100
            ? '${replyInfo.body.substring(0, 100)}...'
            : replyInfo.body;
        return _buildTextQuote(
          senderName: replyInfo.senderName,
          body: body,
        );
    }
  }

  /// 构建文本类型的引用
  ///
  /// Light-1-Client 格式：「发送者：消息内容」
  /// 颜色：#666666，字号 14px
  Widget _buildTextQuote({
    required String senderName,
    required String body,
    bool isSpecial = false,
  }) {
    // Light-1-Client: 引用文字颜色 #666666
    const textColor = Color(0xFF666666);

    // 格式：「发送者：消息内容」
    final displayText = '$senderName：$body';

    return Text(
      displayText,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14, // Light-1-Client: 14px
        color: textColor,
        fontStyle: isSpecial ? FontStyle.italic : FontStyle.normal,
        height: 1.57, // Light-1-Client: lineHeight 1.57
      ),
    );
  }

  /// 构建图片类型的引用
  Widget _buildImageQuote(ImColorScheme colors) {
    const textColor = Color(0xFF666666);

    // 获取图片 URL（优先缩略图，其次原图）
    final imageUrl = replyInfo.thumbnailUrl ?? replyInfo.mediaUrl;

    // 如果有图片 URL，显示缩略图
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${replyInfo.senderName}：',
            style: const TextStyle(
              fontSize: 14,
              color: textColor,
              height: 1.57,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 24,
              height: 24,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 24,
                height: 24,
                color: colors.surfaceVariant,
                child: const Icon(Icons.image, size: 14, color: Colors.grey),
              ),
              errorWidget: (context, url, error) => Container(
                width: 24,
                height: 24,
                color: colors.surfaceVariant,
                child: const Icon(Icons.broken_image, size: 14, color: Colors.grey),
              ),
            ),
          ),
        ],
      );
    }

    // 没有图片 URL 时，显示文字
    return _buildTextQuote(
      senderName: replyInfo.senderName,
      body: '[图片]',
    );
  }

  /// 构建视频类型的引用
  Widget _buildVideoQuote(ImColorScheme colors) {
    const textColor = Color(0xFF666666);

    // 获取视频缩略图 URL
    final thumbnailUrl = replyInfo.thumbnailUrl;

    // 如果有缩略图 URL，显示缩略图
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${replyInfo.senderName}：',
            style: const TextStyle(
              fontSize: 14,
              color: textColor,
              height: 1.57,
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: thumbnailUrl,
                  width: 24,
                  height: 24,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 24,
                    height: 24,
                    color: colors.surfaceVariant,
                    child: const Icon(Icons.videocam, size: 14, color: Colors.grey),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 24,
                    height: 24,
                    color: colors.surfaceVariant,
                    child: const Icon(Icons.videocam, size: 14, color: Colors.grey),
                  ),
                ),
              ),
              // 播放图标
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  size: 8,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      );
    }

    // 没有缩略图时，显示文字
    return _buildTextQuote(
      senderName: replyInfo.senderName,
      body: '[视频]',
    );
  }
}
