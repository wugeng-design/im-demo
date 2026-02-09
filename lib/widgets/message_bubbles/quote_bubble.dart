import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../sdk/models/message.dart';
import '../../theme/im_design_tokens.dart';

/// 引用消息气泡（显示被回复的消息）
///
/// 功能：
/// - 显示被回复消息的预览
/// - 支持图片/视频缩略图
/// - 支持已撤回状态
/// - 左侧有彩色边框指示
class QuoteBubble extends StatelessWidget {
  const QuoteBubble({
    super.key,
    required this.replyInfo,
    required this.isSentByMe,
    this.onTap,
  });

  /// 回复信息
  final ReplyInfo replyInfo;

  /// 是否是自己发送的消息
  final bool isSentByMe;

  /// 点击回调（用于跳转到原消息）
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    // 根据发送者决定颜色
    final backgroundColor = isSentByMe
        ? colors.primary.withValues(alpha: 0.15)
        : colors.surfaceVariant;
    final borderColor = isSentByMe
        ? colors.primary.withValues(alpha: 0.5)
        : colors.textTertiary.withValues(alpha: 0.5);
    final senderColor = colors.primary;
    final bodyColor = isSentByMe ? Colors.black54 : colors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: borderColor,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 主内容
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 发送者名称
                  Text(
                    replyInfo.senderName,
                    style: TextStyle(
                      color: senderColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // 消息内容
                  Text(
                    replyInfo.displayBody,
                    style: TextStyle(
                      color: bodyColor,
                      fontSize: 13,
                      fontStyle: replyInfo.isRetracted
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // 缩略图（图片/视频）
            if (_hasThumbnail) ...[
              const SizedBox(width: 8),
              _buildThumbnail(colors),
            ],
          ],
        ),
      ),
    );
  }

  /// 是否有缩略图
  bool get _hasThumbnail {
    if (replyInfo.isRetracted) return false;
    final hasUrl = replyInfo.thumbnailUrl != null ||
        (replyInfo.messageType == MessageType.image && replyInfo.mediaUrl != null);
    return (replyInfo.messageType == MessageType.image ||
            replyInfo.messageType == MessageType.video) &&
        hasUrl;
  }

  /// 构建缩略图
  Widget _buildThumbnail(ImColorScheme colors) {
    final url = replyInfo.thumbnailUrl ?? replyInfo.mediaUrl ?? '';
    final isVideo = replyInfo.messageType == MessageType.video;

    return Stack(
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: url,
            width: 36,
            height: 36,
            fit: BoxFit.cover,
            placeholder: (context, _) => Container(
              width: 36,
              height: 36,
              color: colors.surfaceVariant,
              child: Icon(
                isVideo ? Icons.videocam : Icons.image,
                size: 18,
                color: Colors.grey,
              ),
            ),
            errorWidget: (context, url, error) => Container(
              width: 36,
              height: 36,
              color: colors.surfaceVariant,
              child: Icon(
                isVideo ? Icons.videocam : Icons.broken_image,
                size: 18,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        // 视频播放图标
        if (isVideo)
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.play_arrow,
              size: 12,
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}
