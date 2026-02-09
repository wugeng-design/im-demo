import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/im_design_tokens.dart';
import '../../theme/message_styles.dart';
import '../im_avatar.dart';
import '../message_status_widget.dart';
import 'message_bubble.dart';

/// 视频消息气泡
class VideoMessageBubble extends StatelessWidget {
  const VideoMessageBubble({
    super.key,
    required this.isSentByMe,
    this.thumbnailUrl,
    this.thumbnailPath,
    this.duration,
    this.width,
    this.height,
    this.status,
    this.uploadProgress,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.showAvatar = false,
    this.onTap,
    this.onLongPress,
    this.onRetry,
    this.onAvatarTap,
  });

  /// 是否是自己发送的
  final bool isSentByMe;

  /// 缩略图 URL
  final String? thumbnailUrl;

  /// 缩略图本地路径
  final String? thumbnailPath;

  /// 视频时长（秒）
  final int? duration;

  /// 视频宽度
  final double? width;

  /// 视频高度
  final double? height;

  /// 消息状态
  final MessageDisplayStatus? status;

  /// 上传进度 (0.0 - 1.0)
  final double? uploadProgress;

  /// 发送者 ID（用于头像占位符颜色）
  final String? senderId;

  /// 发送者名称
  final String? senderName;

  /// 发送者头像 URL
  final String? senderAvatar;

  /// 是否显示头像
  final bool showAvatar;

  /// 点击回调
  final VoidCallback? onTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 重试回调
  final VoidCallback? onRetry;

  /// 头像点击回调
  final VoidCallback? onAvatarTap;

  /// 默认尺寸
  static const double _defaultSize = 180.0;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * MessageStyles.imageMaxWidthRatio;

    // 计算显示尺寸
    final displaySize = _calculateDisplaySize(maxWidth);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧头像（接收的消息）
          if (showAvatar && !isSentByMe) ...[
            GestureDetector(
              onTap: onAvatarTap,
              child: ImAvatar.small(
                userId: senderId ?? '',
                name: senderName,
                avatarUrl: senderAvatar,
              ),
            ),
            const SizedBox(width: 8),
          ],
          // 发送失败图标（同步自 Light-1-Client 样式）
          if (isSentByMe && status == MessageDisplayStatus.failed)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 8),
              child: MessageFailedIndicator(
                onRetry: onRetry ?? () {},
                size: 20,
              ),
            ),
          // 视频容器
          GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: SizedBox(
              width: displaySize.width,
              height: displaySize.height,
              child: Stack(
                children: [
                  // 缩略图
                  ClipRRect(
                    borderRadius: isSentByMe
                        ? MessageStyles.bubbleRadiusSent
                        : MessageStyles.bubbleRadiusReceived,
                    child: _buildThumbnail(colors, displaySize),
                  ),
                  // 播放按钮
                  if (status != MessageDisplayStatus.sending &&
                      (uploadProgress == null || uploadProgress! >= 1.0))
                    _buildPlayButton(),
                  // 时长标签
                  if (duration != null) _buildDurationLabel(),
                  // 上传进度遮罩
                  if (uploadProgress != null && uploadProgress! < 1.0)
                    _buildUploadOverlay(colors, displaySize),
                  // 发送中指示器
                  if (status == MessageDisplayStatus.sending &&
                      uploadProgress == null)
                    _buildSendingIndicator(colors),
                ],
              ),
            ),
          ),
          // 右侧头像（自己发送的消息）
          if (showAvatar && isSentByMe) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onAvatarTap,
              child: ImAvatar.small(
                userId: senderId ?? '',
                name: senderName,
                avatarUrl: senderAvatar,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 计算显示尺寸
  Size _calculateDisplaySize(double maxWidth) {
    final w = width ?? _defaultSize;
    final h = height ?? _defaultSize;

    double scale = 1.0;

    if (w > maxWidth) {
      scale = maxWidth / w;
    }

    final scaledHeight = h * scale;
    if (scaledHeight > MessageStyles.imageMaxHeight) {
      scale = MessageStyles.imageMaxHeight / h;
    }

    final displayWidth =
        (w * scale).clamp(MessageStyles.imageMinSize, maxWidth);
    final displayHeight = (h * scale)
        .clamp(MessageStyles.imageMinSize, MessageStyles.imageMaxHeight);

    return Size(displayWidth, displayHeight);
  }

  /// 构建缩略图
  Widget _buildThumbnail(ImColorScheme colors, Size displaySize) {
    // 优先使用本地缩略图
    if (thumbnailPath != null && thumbnailPath!.isNotEmpty) {
      final file = File(thumbnailPath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: displaySize.width,
          height: displaySize.height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(colors, displaySize);
          },
        );
      }
    }

    // 使用网络缩略图
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return Image.network(
        thumbnailUrl!,
        width: displaySize.width,
        height: displaySize.height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildPlaceholder(colors, displaySize);
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholder(colors, displaySize);
        },
      );
    }

    return _buildPlaceholder(colors, displaySize);
  }

  /// 构建占位符
  Widget _buildPlaceholder(ImColorScheme colors, Size displaySize) {
    final backgroundColor = isSentByMe
        ? colors.messageBubbleSent
        : colors.messageBubbleReceived;

    return Container(
      width: displaySize.width,
      height: displaySize.height,
      color: backgroundColor,
      child: Center(
        child: Icon(
          Icons.videocam_outlined,
          size: 48,
          color: colors.textTertiary,
        ),
      ),
    );
  }

  /// 构建播放按钮
  Widget _buildPlayButton() {
    return Center(
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.play_arrow,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  /// 构建时长标签
  Widget _buildDurationLabel() {
    return Positioned(
      right: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _formatDuration(duration!),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  /// 构建上传进度遮罩
  Widget _buildUploadOverlay(ImColorScheme colors, Size displaySize) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: isSentByMe
              ? MessageStyles.bubbleRadiusSent
              : MessageStyles.bubbleRadiusReceived,
        ),
        child: Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: uploadProgress,
                  strokeWidth: 3,
                  color: Colors.white,
                ),
                Text(
                  '${(uploadProgress! * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建发送中指示器
  Widget _buildSendingIndicator(ImColorScheme colors) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }

  /// 格式化时长
  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
