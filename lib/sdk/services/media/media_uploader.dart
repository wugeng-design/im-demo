/// 媒体文件上传器
///
/// 处理实际的文件上传：
/// - 图片：压缩 + 生成缩略图 + 上传原图 + 上传缩略图
/// - 视频：生成缩略图 + 上传缩略图 + 上传视频
/// - 文件：直接上传
///
/// 设计原则：
/// 1. 上传器只关心"上传"，不关心校验
/// 2. 错误分类：网络错误可重试，文件丢失不可重试
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show Uint8List, debugPrint;

import 'image_processor.dart';
import 'video_processor.dart';
import 'upload_types.dart';

/// 媒体上传配置
class MediaUploadConfig {
  /// 缩略图最大尺寸
  final int thumbnailMaxSize;

  /// 图片压缩质量
  final int imageQuality;

  /// 图片最大宽度
  final int imageMaxWidth;

  /// 图片最大高度
  final int imageMaxHeight;

  const MediaUploadConfig({
    this.thumbnailMaxSize = 200,
    this.imageQuality = 85,
    this.imageMaxWidth = 1920,
    this.imageMaxHeight = 1920,
  });

  static const defaultConfig = MediaUploadConfig();
}

/// 上传函数类型
///
/// [filename] 文件名
/// [data] 文件数据
/// [contentType] MIME 类型
/// [onProgress] 进度回调 (bytesSent, totalBytes)
typedef UploadFunction = Future<UploadResult> Function({
  required String filename,
  required Uint8List data,
  required String contentType,
  UploadProgressCallback? onProgress,
});

/// 媒体文件上传器
///
/// 处理图片/视频/文件的上传逻辑
class MediaUploader {
  /// 图片处理器
  final ImageProcessor _imageProcessor;

  /// 上传函数
  final UploadFunction _upload;

  /// 配置
  final MediaUploadConfig _config;

  MediaUploader({
    required ImageProcessor imageProcessor,
    required UploadFunction upload,
    MediaUploadConfig config = MediaUploadConfig.defaultConfig,
  })  : _imageProcessor = imageProcessor,
        _upload = upload,
        _config = config;

  // ===========================================================================
  // 上传方法
  // ===========================================================================

  /// 上传图片
  ///
  /// 进度分配：
  /// - 0-5%: 读取文件
  /// - 5-10%: 生成缩略图
  /// - 10-90%: 上传原图
  /// - 90-100%: 上传缩略图
  Future<MediaUploadResult> uploadImage({
    required String messageId,
    required String localFilePath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final file = File(localFilePath);

      // 检查文件（可能在队列等待期间被删除）
      if (!await file.exists()) {
        return MediaUploadResult.failure(
          messageId: messageId,
          errorMessage: '文件不存在: $localFilePath',
          failureType: UploadFailureType.fileNotFound,
        );
      }

      // 1. 读取原图数据 (0-5%)
      onProgress?.call(0.02);
      final imageData = await file.readAsBytes();
      final fileName = file.uri.pathSegments.last;
      final mimeType = _getImageMimeType(fileName);
      onProgress?.call(0.05);

      debugPrint('[MediaUploader] 准备上传原图: $messageId (${(imageData.length / 1024).toStringAsFixed(1)}KB)');

      // 2. 生成缩略图（用于预览）(5-10%)
      String? thumbnailUrl;
      final thumbnail = await _imageProcessor.generateThumbnailBytes(
        data: imageData,
        filename: fileName,
        maxSize: _config.thumbnailMaxSize,
      );
      onProgress?.call(0.10);

      // 3. 上传原图 (10-90%)
      debugPrint('[MediaUploader] 上传图片: $messageId');

      final uploadResult = await _upload(
        filename: fileName,
        data: imageData,
        contentType: mimeType,
        onProgress: (sent, total) {
          // 上传进度映射到 10%-90%
          final uploadProgress = total > 0 ? sent / total : 0.0;
          final overallProgress = 0.10 + (uploadProgress * 0.80);
          onProgress?.call(overallProgress);
        },
      );

      // 4. 检查上传结果
      final downloadUrl = uploadResult.downloadUrl;
      if (downloadUrl == null || downloadUrl.isEmpty) {
        return _handleUploadError(messageId, uploadResult.error ?? '上传失败');
      }

      // 5. 上传缩略图（可选）(90-100%)
      onProgress?.call(0.90);
      if (thumbnail != null) {
        final thumbResult = await _upload(
          filename: 'thumb_$fileName',
          data: thumbnail.data,
          contentType: thumbnail.mimeType,
        );
        if (thumbResult.success) {
          thumbnailUrl = thumbResult.downloadUrl;
        }
      }

      // 6. 完成
      onProgress?.call(1.0);
      debugPrint('[MediaUploader] 图片上传完成: $messageId -> $downloadUrl');

      return MediaUploadResult.success(
        messageId: messageId,
        remoteUrl: downloadUrl,
        thumbnailUrl: thumbnailUrl,
      );
    } catch (e) {
      debugPrint('[MediaUploader] 图片上传失败: $messageId - $e');
      return _handleException(messageId, e);
    }
  }

  /// 上传视频
  ///
  /// 进度分配（更平滑）：
  /// - 0-10%: 生成缩略图
  /// - 10-20%: 上传缩略图
  /// - 20-30%: 读取视频文件
  /// - 30-100%: 上传视频
  Future<MediaUploadResult> uploadVideo({
    required String messageId,
    required String localFilePath,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final file = File(localFilePath);

      // 检查文件
      if (!await file.exists()) {
        return MediaUploadResult.failure(
          messageId: messageId,
          errorMessage: '文件不存在: $localFilePath',
          failureType: UploadFailureType.fileNotFound,
        );
      }

      // 1. 生成缩略图 (0-10%)
      String? thumbnailUrl;
      debugPrint('[MediaUploader] 生成视频缩略图: $messageId');
      onProgress?.call(0.05);
      final thumbnailData = await VideoProcessor.generateThumbnail(
        localFilePath,
        maxWidth: 320,
      );
      onProgress?.call(0.10);

      // 2. 上传缩略图（如果有）(10-20%)
      if (thumbnailData != null) {
        debugPrint('[MediaUploader] 开始上传视频缩略图: $messageId');
        final thumbResult = await _upload(
          filename: 'thumb_$messageId.jpg',
          data: thumbnailData,
          contentType: 'image/jpeg',
        );
        if (thumbResult.success) {
          thumbnailUrl = thumbResult.downloadUrl;
          debugPrint('[MediaUploader] 缩略图上传成功: $thumbnailUrl');
        } else {
          debugPrint('[MediaUploader] 缩略图上传失败: ${thumbResult.error}');
        }
      } else {
        debugPrint('[MediaUploader] 视频缩略图生成失败，将不包含缩略图');
      }
      onProgress?.call(0.20);

      // 3. 读取视频文件 (20-30%)
      debugPrint('[MediaUploader] 读取视频文件: $messageId');
      onProgress?.call(0.25);
      final videoBytes = await file.readAsBytes();
      final mimeType = VideoProcessor.getMimeType(localFilePath);
      final fileName = file.uri.pathSegments.last;
      onProgress?.call(0.30);

      // 4. 上传视频 (30-100%)
      debugPrint('[MediaUploader] 上传视频: $messageId (${(videoBytes.length / 1024 / 1024).toStringAsFixed(1)}MB)');

      final uploadResult = await _upload(
        filename: fileName,
        data: videoBytes,
        contentType: mimeType,
        onProgress: (sent, total) {
          // 上传进度映射到 30%-100%
          final uploadProgress = total > 0 ? sent / total : 0.0;
          final overallProgress = 0.30 + (uploadProgress * 0.70);
          onProgress?.call(overallProgress);
        },
      );

      // 5. 检查上传结果
      final downloadUrl = uploadResult.downloadUrl;
      if (downloadUrl == null || downloadUrl.isEmpty) {
        return _handleUploadError(messageId, uploadResult.error ?? '视频上传失败');
      }

      // 6. 完成
      onProgress?.call(1.0);
      debugPrint('[MediaUploader] 视频上传完成: $messageId');
      debugPrint('[MediaUploader]    视频 URL: $downloadUrl');
      debugPrint('[MediaUploader]    缩略图 URL: ${thumbnailUrl ?? "无"}');

      return MediaUploadResult.success(
        messageId: messageId,
        remoteUrl: downloadUrl,
        thumbnailUrl: thumbnailUrl,
      );
    } catch (e) {
      debugPrint('[MediaUploader] 视频上传失败: $messageId - $e');
      return _handleException(messageId, e);
    }
  }

  /// 上传文件（不处理，直接上传）
  ///
  /// 进度分配：
  /// - 0-10%: 读取文件
  /// - 10-100%: 上传文件
  Future<MediaUploadResult> uploadFile({
    required String messageId,
    required String localFilePath,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final file = File(localFilePath);

      // 检查文件
      if (!await file.exists()) {
        return MediaUploadResult.failure(
          messageId: messageId,
          errorMessage: '文件不存在: $localFilePath',
          failureType: UploadFailureType.fileNotFound,
        );
      }

      // 1. 读取文件 (0-10%)
      debugPrint('[MediaUploader] 读取文件: $messageId');
      onProgress?.call(0.02);
      final fileBytes = await file.readAsBytes();
      final fileName = file.uri.pathSegments.last;
      onProgress?.call(0.10);

      // 2. 上传文件 (10-100%)
      debugPrint('[MediaUploader] 上传文件: $messageId (${(fileBytes.length / 1024 / 1024).toStringAsFixed(1)}MB)');

      final uploadResult = await _upload(
        filename: fileName,
        data: fileBytes,
        contentType: mimeType,
        onProgress: (sent, total) {
          // 上传进度映射到 10%-100%
          final uploadProgress = total > 0 ? sent / total : 0.0;
          final overallProgress = 0.10 + (uploadProgress * 0.90);
          onProgress?.call(overallProgress);
        },
      );

      // 检查上传结果
      final downloadUrl = uploadResult.downloadUrl;
      if (downloadUrl == null || downloadUrl.isEmpty) {
        return _handleUploadError(messageId, uploadResult.error ?? '文件上传失败');
      }

      // 完成
      onProgress?.call(1.0);
      debugPrint('[MediaUploader] 文件上传完成: $messageId -> $downloadUrl');

      return MediaUploadResult.success(
        messageId: messageId,
        remoteUrl: downloadUrl,
      );
    } catch (e) {
      debugPrint('[MediaUploader] 文件上传失败: $messageId - $e');
      return _handleException(messageId, e);
    }
  }

  // ===========================================================================
  // 错误处理
  // ===========================================================================

  /// 处理上传错误（区分网络/服务器错误）
  MediaUploadResult _handleUploadError(String messageId, String error) {
    final lowerError = error.toLowerCase();
    final isNetworkError = lowerError.contains('network') ||
        lowerError.contains('socket') ||
        lowerError.contains('timeout') ||
        lowerError.contains('connection');

    return MediaUploadResult.failure(
      messageId: messageId,
      errorMessage: error,
      failureType: isNetworkError
          ? UploadFailureType.networkError
          : UploadFailureType.serverError,
    );
  }

  /// 处理异常
  MediaUploadResult _handleException(String messageId, Object e) {
    final error = e.toString();
    UploadFailureType failureType;

    if (e is FileSystemException) {
      failureType = UploadFailureType.fileNotFound;
    } else if (error.contains('socket') ||
        error.contains('network') ||
        error.contains('timeout')) {
      failureType = UploadFailureType.networkError;
    } else {
      failureType = UploadFailureType.unknown;
    }

    return MediaUploadResult.failure(
      messageId: messageId,
      errorMessage: error,
      failureType: failureType,
    );
  }

  // ===========================================================================
  // 工具方法
  // ===========================================================================

  /// 根据文件名获取图片 MIME 类型
  String _getImageMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}
