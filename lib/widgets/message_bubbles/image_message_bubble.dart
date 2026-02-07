import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/im_design_tokens.dart';
import '../../theme/message_styles.dart';
import 'message_bubble.dart';

/// 图片消息气泡
class ImageMessageBubble extends StatelessWidget {
  const ImageMessageBubble({
    super.key,
    required this.isSentByMe,
    this.imageUrl,
    this.localFilePath,
    this.width,
    this.height,
    this.status,
    this.uploadProgress,
    this.onTap,
    this.onLongPress,
    this.onRetry,
  });

  /// 是否是自己发送的
  final bool isSentByMe;

  /// 图片 URL（网络图片）
  final String? imageUrl;

  /// 本地文件路径
  final String? localFilePath;

  /// 图片宽度
  final double? width;

  /// 图片高度
  final double? height;

  /// 消息状态
  final MessageDisplayStatus? status;

  /// 上传进度 (0.0 - 1.0)
  final double? uploadProgress;

  /// 点击回调
  final VoidCallback? onTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 重试回调
  final VoidCallback? onRetry;

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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 发送失败图标
          if (isSentByMe && status == MessageDisplayStatus.failed)
            GestureDetector(
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.error_outline,
                  size: 18,
                  color: colors.error,
                ),
              ),
            ),
          // 图片容器
          GestureDetector(
            onTap: onTap,
            onLongPress: onLongPress,
            child: SizedBox(
              width: displaySize.width,
              height: displaySize.height,
              child: Stack(
                children: [
                  // 图片
                  ClipRRect(
                    borderRadius: isSentByMe
                        ? MessageStyles.bubbleRadiusSent
                        : MessageStyles.bubbleRadiusReceived,
                    child: _buildImage(colors, displaySize),
                  ),
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

  /// 构建图片
  Widget _buildImage(ImColorScheme colors, Size displaySize) {
    // 优先使用本地文件
    if (localFilePath != null && localFilePath!.isNotEmpty) {
      final file = File(localFilePath!);
      if (file.existsSync()) {
        return Image.file(
          file,
          width: displaySize.width,
          height: displaySize.height,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildErrorPlaceholder(colors, displaySize);
          },
        );
      }
    }

    // 使用网络图片
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return Image.network(
        imageUrl!,
        width: displaySize.width,
        height: displaySize.height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder(colors, displaySize);
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder(colors, displaySize);
        },
      );
    }

    return _buildErrorPlaceholder(colors, displaySize);
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

  /// 构建加载占位符
  Widget _buildLoadingPlaceholder(ImColorScheme colors, Size displaySize) {
    final backgroundColor = isSentByMe
        ? colors.messageBubbleSent
        : colors.messageBubbleReceived;

    return Container(
      width: displaySize.width,
      height: displaySize.height,
      color: backgroundColor,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: colors.textTertiary,
        ),
      ),
    );
  }

  /// 构建错误占位符
  Widget _buildErrorPlaceholder(ImColorScheme colors, Size displaySize) {
    final backgroundColor = isSentByMe
        ? colors.messageBubbleSent
        : colors.messageBubbleReceived;

    return Container(
      width: displaySize.width,
      height: displaySize.height,
      color: backgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 32,
            color: colors.textTertiary,
          ),
          const SizedBox(height: 4),
          Text(
            '加载失败',
            style: MessageStyles.systemText(colors.textTertiary),
          ),
        ],
      ),
    );
  }
}
