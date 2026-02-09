/// 媒体 Fallback 消息气泡
///
/// 用于显示无法正常解析的媒体消息（如对方客户端发送的纯文本格式媒体消息）
///
/// 场景：
/// - 对方客户端发送视频/图片时未包含 OOB/SIMS 扩展
/// - body 格式为 "【视频】\n文件名" 或 "[图片]\n文件名"
/// - 无法获取真正的媒体 URL，只能显示占位符
library;

import 'package:flutter/material.dart';

import '../../theme/im_design_tokens.dart';
import '../../theme/message_styles.dart';

/// 媒体类型枚举
enum MediaFallbackType {
  video,
  image,
  audio,
  file,
}

/// 媒体 Fallback 气泡
///
/// 显示一个简洁的媒体占位符，包含图标和类型名称
class MediaFallbackBubble extends StatelessWidget {
  const MediaFallbackBubble({
    super.key,
    required this.mediaType,
    required this.isSentByMe,
    this.fileName,
    this.onTap,
    this.onLongPress,
  });

  /// 媒体类型
  final MediaFallbackType mediaType;

  /// 是否是自己发送的
  final bool isSentByMe;

  /// 文件名（可选）
  final String? fileName;

  /// 点击回调
  final VoidCallback? onTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 200,
          minWidth: 120,
        ),
        padding: const EdgeInsets.all(12),
        decoration: MessageStyles.bubble(
          isSentByMe ? colors.messageBubbleSent : colors.messageBubbleReceived,
          radius: isSentByMe
              ? MessageStyles.bubbleRadiusSent
              : MessageStyles.bubbleRadiusReceived,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 媒体图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIcon(),
                size: 24,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 10),
            // 类型名称和文件名
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _getTypeName(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSentByMe ? Colors.black87 : colors.textPrimary,
                    ),
                  ),
                  if (fileName != null && fileName!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _getShortFileName(fileName!),
                      style: TextStyle(
                        fontSize: 11,
                        color: isSentByMe
                            ? Colors.black45
                            : colors.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 获取媒体图标
  IconData _getIcon() {
    switch (mediaType) {
      case MediaFallbackType.video:
        return Icons.videocam_outlined;
      case MediaFallbackType.image:
        return Icons.image_outlined;
      case MediaFallbackType.audio:
        return Icons.audiotrack_outlined;
      case MediaFallbackType.file:
        return Icons.insert_drive_file_outlined;
    }
  }

  /// 获取类型名称
  String _getTypeName() {
    switch (mediaType) {
      case MediaFallbackType.video:
        return '视频';
      case MediaFallbackType.image:
        return '图片';
      case MediaFallbackType.audio:
        return '语音';
      case MediaFallbackType.file:
        return '文件';
    }
  }

  /// 获取简化的文件名（最多显示 15 个字符）
  String _getShortFileName(String name) {
    if (name.length <= 15) return name;
    // 保留前 8 个字符 + ... + 后 4 个字符（含扩展名）
    final ext = name.contains('.') ? name.split('.').last : '';
    if (ext.isNotEmpty && ext.length <= 4) {
      return '${name.substring(0, 8)}....$ext';
    }
    return '${name.substring(0, 12)}...';
  }

  /// 解析文本消息中的媒体 fallback 信息
  ///
  /// 返回 (MediaFallbackType, fileName) 或 null（如果不是媒体 fallback）
  static (MediaFallbackType, String?)? parseMediaFallback(String text) {
    final trimmed = text.trim();

    // 检测视频
    if (trimmed.startsWith('【视频】') || trimmed.startsWith('[视频]')) {
      final fileName = _extractFileName(trimmed, '【视频】', '[视频]');
      return (MediaFallbackType.video, fileName);
    }

    // 检测图片
    if (trimmed.startsWith('【图片】') || trimmed.startsWith('[图片]')) {
      final fileName = _extractFileName(trimmed, '【图片】', '[图片]');
      return (MediaFallbackType.image, fileName);
    }

    // 检测语音
    if (trimmed.startsWith('【语音】') || trimmed.startsWith('[语音]')) {
      final fileName = _extractFileName(trimmed, '【语音】', '[语音]');
      return (MediaFallbackType.audio, fileName);
    }

    // 检测文件
    if (trimmed.startsWith('【文件】') || trimmed.startsWith('[文件]')) {
      final fileName = _extractFileName(trimmed, '【文件】', '[文件]');
      return (MediaFallbackType.file, fileName);
    }

    return null;
  }

  /// 提取文件名
  static String? _extractFileName(String text, String prefix1, String prefix2) {
    String remaining;
    if (text.startsWith(prefix1)) {
      remaining = text.substring(prefix1.length);
    } else {
      remaining = text.substring(prefix2.length);
    }

    // 去除前导空白和换行
    remaining = remaining.trim();
    if (remaining.isEmpty) return null;

    // 如果有多行，取第一行作为文件名
    final lines = remaining.split('\n');
    return lines.first.trim();
  }
}
