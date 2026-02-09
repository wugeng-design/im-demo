/// 视频处理服务
///
/// 功能：
/// - 获取视频元数据（宽高、时长）
/// - 生成视频缩略图
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:video_thumbnail/video_thumbnail.dart' as video_thumbnail;

/// 视频信息
class VideoInfo {
  /// 视频宽度
  final int width;

  /// 视频高度
  final int height;

  /// 时长（毫秒）
  final int durationMs;

  /// 文件大小（字节）
  final int fileSize;

  const VideoInfo({
    required this.width,
    required this.height,
    required this.durationMs,
    required this.fileSize,
  });

  /// 时长（秒）
  double get durationSeconds => durationMs / 1000.0;

  /// 宽高比
  double get aspectRatio => height > 0 ? width / height : 1.0;

  /// 格式化时长（MM:SS）
  String get formattedDuration {
    final totalSeconds = durationMs ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  String toString() =>
      'VideoInfo(${width}x$height, $formattedDuration, ${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB)';
}

/// 视频处理服务
class VideoProcessor {
  /// 获取视频信息
  ///
  /// 注意：目前只返回文件大小，宽高和时长需要依赖其他库
  static Future<VideoInfo?> getVideoInfo(String videoPath) async {
    if (kIsWeb) {
      debugPrint('[VideoProcessor] Web 平台不支持获取视频信息');
      return null;
    }

    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        debugPrint('[VideoProcessor] 视频文件不存在: $videoPath');
        return null;
      }

      final fileSize = await file.length();

      // 返回基础信息，宽高时长默认值
      // 在 Flutter 中，完整的视频元数据需要 video_compress 包
      // 但该包在某些平台上可能有兼容性问题
      return VideoInfo(
        width: 0, // 无法获取
        height: 0, // 无法获取
        durationMs: 0, // 无法获取
        fileSize: fileSize,
      );
    } catch (e) {
      debugPrint('[VideoProcessor] 获取视频信息失败: $e');
      return null;
    }
  }

  /// 生成视频缩略图
  ///
  /// [videoPath] 视频文件路径
  /// [maxWidth] 缩略图最大宽度
  /// [quality] 缩略图质量 (0-100)
  /// [timeMs] 截取时间点（毫秒）
  static Future<Uint8List?> generateThumbnail(
    String videoPath, {
    int maxWidth = 512,
    int quality = 75,
    int timeMs = 0,
  }) async {
    // video_thumbnail 仅支持 iOS 和 Android
    if (kIsWeb) {
      debugPrint('[VideoProcessor] Web 平台不支持视频缩略图生成');
      return null;
    }

    // 检查桌面平台
    if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
      debugPrint('[VideoProcessor] 桌面平台不支持视频缩略图生成');
      return null;
    }

    try {
      debugPrint('[VideoProcessor] 生成视频缩略图: $videoPath');

      final thumbnailData =
          await video_thumbnail.VideoThumbnail.thumbnailData(
        video: videoPath,
        imageFormat: video_thumbnail.ImageFormat.JPEG,
        maxWidth: maxWidth,
        quality: quality,
        timeMs: timeMs,
      );

      if (thumbnailData != null) {
        debugPrint('[VideoProcessor] 缩略图生成成功 (${(thumbnailData.length / 1024).toStringAsFixed(1)}KB)');
        return thumbnailData;
      } else {
        debugPrint('[VideoProcessor] 缩略图生成失败');
        return null;
      }
    } catch (e) {
      debugPrint('[VideoProcessor] 缩略图生成异常: $e');
      return null;
    }
  }

  /// 检查文件是否为视频
  static bool isVideoFile(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    const videoExtensions = {
      'mp4', 'mov', 'avi', 'mkv', 'webm', 'flv', 'wmv', 'm4v',
      '3gp', 'ts', 'mts', 'm2ts', 'vob', 'ogv',
    };
    return videoExtensions.contains(ext);
  }

  /// 根据文件名获取视频 MIME 类型
  static String getMimeType(String fileName) {
    final ext = fileName.toLowerCase().split('.').last;
    const mimeTypes = {
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'avi': 'video/x-msvideo',
      'mkv': 'video/x-matroska',
      'webm': 'video/webm',
      'flv': 'video/x-flv',
      'wmv': 'video/x-ms-wmv',
      'm4v': 'video/x-m4v',
      '3gp': 'video/3gpp',
      'ts': 'video/mp2t',
      'ogv': 'video/ogg',
    };
    return mimeTypes[ext] ?? 'video/mp4';
  }

  /// 格式化时长（秒 -> MM:SS）
  static String formatDuration(double? seconds) {
    if (seconds == null || seconds <= 0) return '00:00';
    final totalSeconds = seconds.toInt();
    final minutes = totalSeconds ~/ 60;
    final secs = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
