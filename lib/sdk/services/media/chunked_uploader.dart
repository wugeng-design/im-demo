/// 分块上传服务
///
/// 支持大文件分块上传，兼容 XEP-0363 HTTP File Upload
/// 适用于需要分块传输的大文件场景
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb, Uint8List, debugPrint;
import 'package:http/http.dart' as http;

import 'upload_types.dart';

/// 格式化字节数
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
}

/// 分块上传器
///
/// 将大文件分割成小块进行上传，支持进度跟踪
///
/// 使用示例：
/// ```dart
/// await ChunkedUploader.uploadInChunks(
///   file: File('path/to/large/file.mp4'),
///   uploadUrl: slot.putUrl,
///   contentType: 'video/mp4',
///   onProgress: (sent, total) {
///     print('进度: ${(sent / total * 100).toStringAsFixed(1)}%');
///   },
/// );
/// ```
class ChunkedUploader {
  /// 默认分块大小：5MB
  static const int defaultChunkSize = 5 * 1024 * 1024;

  /// 最小分块大小：1MB
  static const int minChunkSize = 1 * 1024 * 1024;

  /// 最大分块大小：50MB
  static const int maxChunkSize = 50 * 1024 * 1024;

  /// 分块上传文件
  ///
  /// [file] 要上传的文件
  /// [uploadUrl] 上传目标URL（来自 UploadSlot.putUrl）
  /// [contentType] 文件MIME类型
  /// [headers] 额外的HTTP头（来自 UploadSlot.headers）
  /// [chunkSize] 分块大小（字节）
  /// [onProgress] 进度回调
  /// [onChunkComplete] 分块完成回调
  ///
  /// 注意：此方法需要服务器支持分块上传（Content-Range头）
  static Future<void> uploadInChunks({
    required File file,
    required String uploadUrl,
    required String contentType,
    Map<String, String>? headers,
    int chunkSize = defaultChunkSize,
    UploadProgressCallback? onProgress,
    void Function(int chunkIndex, int totalChunks)? onChunkComplete,
  }) async {
    if (kIsWeb) {
      throw UnsupportedError('Web 平台不支持分块上传');
    }

    final fileSize = await file.length();
    final totalChunks = (fileSize / chunkSize).ceil();
    int uploadedBytes = 0;

    debugPrint('[ChunkedUploader] 开始分块上传 - 文件大小: ${_formatBytes(fileSize)}, '
        '分块大小: ${_formatBytes(chunkSize)}, 总分块数: $totalChunks');

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = min(start + chunkSize, fileSize);
      final chunkLength = end - start;

      debugPrint('[ChunkedUploader] 上传分块 ${i + 1}/$totalChunks (${_formatBytes(chunkLength)})');

      // 读取分块数据
      final chunkData = await _readChunk(file, start, end);

      // 上传分块
      await _uploadChunk(
        uploadUrl: uploadUrl,
        chunkData: chunkData,
        startByte: start,
        endByte: end,
        totalSize: fileSize,
        contentType: contentType,
        extraHeaders: headers,
      );

      uploadedBytes += chunkLength;
      onProgress?.call(uploadedBytes, fileSize);
      onChunkComplete?.call(i, totalChunks);

      debugPrint('[ChunkedUploader] 分块 ${i + 1}/$totalChunks 上传完成');
    }

    debugPrint('[ChunkedUploader] 所有分块上传完成');
  }

  /// 从 Uint8List 分块上传
  ///
  /// 适用于已经在内存中的数据
  static Future<void> uploadDataInChunks({
    required Uint8List data,
    required String uploadUrl,
    required String contentType,
    Map<String, String>? headers,
    int chunkSize = defaultChunkSize,
    UploadProgressCallback? onProgress,
    void Function(int chunkIndex, int totalChunks)? onChunkComplete,
  }) async {
    final totalSize = data.length;
    final totalChunks = (totalSize / chunkSize).ceil();
    int uploadedBytes = 0;

    debugPrint('[ChunkedUploader] 开始分块上传 (内存数据) - 数据大小: ${_formatBytes(totalSize)}, '
        '总分块数: $totalChunks');

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = min(start + chunkSize, totalSize);
      final chunkData = data.sublist(start, end);

      await _uploadChunk(
        uploadUrl: uploadUrl,
        chunkData: chunkData,
        startByte: start,
        endByte: end,
        totalSize: totalSize,
        contentType: contentType,
        extraHeaders: headers,
      );

      uploadedBytes += chunkData.length;
      onProgress?.call(uploadedBytes, totalSize);
      onChunkComplete?.call(i, totalChunks);
    }

    debugPrint('[ChunkedUploader] 所有分块上传完成');
  }

  /// 读取文件分块
  static Future<Uint8List> _readChunk(File file, int start, int end) async {
    final stream = file.openRead(start, end);
    final chunks = await stream.toList();
    final flatBytes = chunks.expand((chunk) => chunk).toList();
    return Uint8List.fromList(flatBytes);
  }

  /// 上传单个分块
  static Future<void> _uploadChunk({
    required String uploadUrl,
    required Uint8List chunkData,
    required int startByte,
    required int endByte,
    required int totalSize,
    required String contentType,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse(uploadUrl);
    final request = http.Request('PUT', uri);

    // 设置标准头
    request.headers['Content-Type'] = contentType;
    request.headers['Content-Range'] = 'bytes $startByte-${endByte - 1}/$totalSize';
    request.headers['Content-Length'] = chunkData.length.toString();

    // 添加额外头（如 Authorization）
    if (extraHeaders != null) {
      request.headers.addAll(extraHeaders);
    }

    request.bodyBytes = chunkData;

    debugPrint('[ChunkedUploader] Content-Range: bytes $startByte-${endByte - 1}/$totalSize');

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      // 接受的状态码：200 OK, 201 Created, 206 Partial, 308 Resume
      if (response.statusCode != 200 &&
          response.statusCode != 201 &&
          response.statusCode != 206 &&
          response.statusCode != 308) {
        throw ChunkedUploadException(
          '分块上传失败',
          statusCode: response.statusCode,
          message: response.reasonPhrase,
        );
      }
    } finally {
      client.close();
    }
  }

  /// 检查是否应该使用分块上传
  ///
  /// [fileSize] 文件大小（字节）
  /// [threshold] 阈值（字节），默认10MB
  static bool shouldUseChunkedUpload(int fileSize, {int threshold = 10 * 1024 * 1024}) {
    return fileSize > threshold;
  }

  /// 计算最优分块大小
  ///
  /// [fileSize] 文件大小
  /// [targetChunks] 目标分块数量（默认20个）
  static int calculateOptimalChunkSize(int fileSize, {int targetChunks = 20}) {
    if (fileSize <= 0) return defaultChunkSize;

    // 计算达到目标分块数的分块大小
    int calculatedSize = (fileSize / targetChunks).ceil();

    // 确保在允许范围内
    calculatedSize = calculatedSize.clamp(minChunkSize, maxChunkSize);

    // 对齐到1MB边界
    calculatedSize = ((calculatedSize / minChunkSize).ceil() * minChunkSize);

    return calculatedSize;
  }
}

/// 分块上传异常
class ChunkedUploadException implements Exception {
  final String error;
  final int? statusCode;
  final String? message;

  const ChunkedUploadException(
    this.error, {
    this.statusCode,
    this.message,
  });

  @override
  String toString() {
    if (statusCode != null) {
      return 'ChunkedUploadException: $error (HTTP $statusCode: $message)';
    }
    return 'ChunkedUploadException: $error';
  }
}

/// 分块上传配置
class ChunkedUploadConfig {
  /// 分块大小
  final int chunkSize;

  /// 使用分块上传的文件大小阈值
  final int threshold;

  /// 目标分块数（自动计算分块大小时使用）
  final int targetChunks;

  const ChunkedUploadConfig({
    this.chunkSize = ChunkedUploader.defaultChunkSize,
    this.threshold = 10 * 1024 * 1024, // 10MB
    this.targetChunks = 20,
  });

  /// 默认配置
  static const ChunkedUploadConfig defaultConfig = ChunkedUploadConfig();

  /// 大文件配置（10MB 分块，50MB 阈值）
  static const ChunkedUploadConfig largeFile = ChunkedUploadConfig(
    chunkSize: 10 * 1024 * 1024,
    threshold: 50 * 1024 * 1024,
    targetChunks: 50,
  );

  /// 低带宽配置（1MB 分块，5MB 阈值）
  static const ChunkedUploadConfig lowBandwidth = ChunkedUploadConfig(
    chunkSize: 1 * 1024 * 1024,
    threshold: 5 * 1024 * 1024,
    targetChunks: 100,
  );
}
