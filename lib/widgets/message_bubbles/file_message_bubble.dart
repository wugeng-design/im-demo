import 'package:flutter/material.dart';

import '../../theme/im_design_tokens.dart';
import '../../theme/message_styles.dart';
import '../im_avatar.dart';
import '../message_status_widget.dart';
import 'message_bubble.dart';

/// 文件消息气泡
class FileMessageBubble extends StatelessWidget {
  const FileMessageBubble({
    super.key,
    required this.fileName,
    required this.isSentByMe,
    this.fileSize,
    this.mimeType,
    this.timestamp,
    this.status,
    this.uploadProgress,
    this.downloadProgress,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.showAvatar = false,
    this.onTap,
    this.onLongPress,
    this.onRetry,
    this.onAvatarTap,
  });

  /// 文件名
  final String fileName;

  /// 是否是自己发送的
  final bool isSentByMe;

  /// 文件大小（字节）
  final int? fileSize;

  /// MIME 类型
  final String? mimeType;

  /// 时间戳
  final DateTime? timestamp;

  /// 消息状态
  final MessageDisplayStatus? status;

  /// 上传进度 (0.0 - 1.0)
  final double? uploadProgress;

  /// 下载进度 (0.0 - 1.0)
  final double? downloadProgress;

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

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

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
          // 文件气泡
          Flexible(
            child: GestureDetector(
              onTap: onTap,
              onLongPress: onLongPress,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.all(12),
                decoration: MessageStyles.bubble(
                  isSentByMe
                      ? colors.messageBubbleSent
                      : colors.messageBubbleReceived,
                  radius: isSentByMe
                      ? MessageStyles.bubbleRadiusSent
                      : MessageStyles.bubbleRadiusReceived,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 文件图标
                    _buildFileIcon(colors),
                    const SizedBox(width: 12),
                    // 文件信息
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 文件名
                          Text(
                            fileName,
                            style: TextStyle(
                              color: isSentByMe
                                  ? Colors.black87
                                  : colors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // 文件大小和状态
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(child: _buildSubtitle(colors)),
                              // 已读回执状态
                              if (isSentByMe &&
                                  status != null &&
                                  status != MessageDisplayStatus.failed &&
                                  status != MessageDisplayStatus.sending &&
                                  uploadProgress == null) ...[
                                const SizedBox(width: 6),
                                _buildStatusIcon(colors),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

  /// 构建文件图标
  Widget _buildFileIcon(ImColorScheme colors) {
    // 根据文件类型选择图标
    IconData icon;
    Color iconColor;

    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        icon = Icons.picture_as_pdf;
        iconColor = Colors.red;
        break;
      case 'doc':
      case 'docx':
        icon = Icons.description;
        iconColor = Colors.blue;
        break;
      case 'xls':
      case 'xlsx':
        icon = Icons.table_chart;
        iconColor = Colors.green;
        break;
      case 'ppt':
      case 'pptx':
        icon = Icons.slideshow;
        iconColor = Colors.orange;
        break;
      case 'zip':
      case 'rar':
      case '7z':
        icon = Icons.folder_zip;
        iconColor = Colors.amber;
        break;
      case 'mp3':
      case 'wav':
      case 'aac':
        icon = Icons.audio_file;
        iconColor = Colors.purple;
        break;
      default:
        icon = Icons.insert_drive_file;
        iconColor = colors.textSecondary;
    }

    // 如果正在上传或下载，显示进度
    if ((uploadProgress != null && uploadProgress! < 1.0) ||
        (downloadProgress != null && downloadProgress! < 1.0)) {
      final progress = uploadProgress ?? downloadProgress ?? 0;
      return SizedBox(
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: progress,
              strokeWidth: 3,
              color: colors.primary,
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 9,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: iconColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor, size: 24),
    );
  }

  /// 构建副标题（文件大小和状态）
  Widget _buildSubtitle(ImColorScheme colors) {
    final parts = <String>[];

    // 文件大小
    if (fileSize != null) {
      parts.add(_formatFileSize(fileSize!));
    }

    // 状态文本
    if (status == MessageDisplayStatus.sending) {
      parts.add('发送中...');
    } else if (uploadProgress != null && uploadProgress! < 1.0) {
      parts.add('上传中 ${(uploadProgress! * 100).toInt()}%');
    } else if (downloadProgress != null && downloadProgress! < 1.0) {
      parts.add('下载中 ${(downloadProgress! * 100).toInt()}%');
    }

    return Text(
      parts.join(' · '),
      style: TextStyle(
        color: isSentByMe ? Colors.black45 : colors.textTertiary,
        fontSize: 12,
      ),
    );
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 构建状态图标（已发送/已送达/已读）
  Widget _buildStatusIcon(ImColorScheme colors) {
    final IconData icon;
    final Color color;

    switch (status!) {
      case MessageDisplayStatus.sent:
        icon = Icons.check;
        color = isSentByMe ? Colors.black45 : colors.textTertiary;
      case MessageDisplayStatus.delivered:
        icon = Icons.done_all;
        color = isSentByMe ? Colors.black45 : colors.textTertiary;
      case MessageDisplayStatus.read:
        icon = Icons.done_all;
        color = colors.info; // 蓝色表示已读
      default:
        return const SizedBox.shrink();
    }

    return Icon(icon, size: 14, color: color);
  }
}
