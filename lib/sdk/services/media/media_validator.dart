/// 媒体文件校验器
///
/// 发送前校验：
/// - 文件存在性
/// - 扩展名格式
/// - Magic Bytes 验证
/// - 文件大小限制
///
/// 设计原则：
/// 1. 校验失败不创建消息气泡
/// 2. 区分可重试和不可重试的失败
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import 'file_magic_bytes.dart';
import 'upload_types.dart';

/// 媒体校验配置
class MediaValidatorConfig {
  /// 最大图片大小 (MB)
  final int maxImageSizeMb;

  /// 最大视频大小 (MB)
  final int maxVideoSizeMb;

  /// 最大文件大小 (MB)
  final int maxFileSizeMb;

  const MediaValidatorConfig({
    this.maxImageSizeMb = 10,
    this.maxVideoSizeMb = 100,
    this.maxFileSizeMb = 100,
  });

  static const defaultConfig = MediaValidatorConfig();
}

/// 媒体文件校验器
///
/// 在创建占位消息前调用，失败则不创建气泡
class MediaValidator {
  /// 配置
  final MediaValidatorConfig config;

  /// 支持的图片格式
  static const imageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp',
    '.heic',
  ];

  /// 支持的视频格式
  static const videoExtensions = [
    '.mp4',
    '.mov',
    '.avi',
    '.mkv',
    '.webm',
    '.3gp',
  ];

  /// 支持的音频格式
  static const audioExtensions = [
    '.mp3',
    '.m4a',
    '.wav',
    '.aac',
    '.ogg',
  ];

  MediaValidator({this.config = MediaValidatorConfig.defaultConfig});

  // ===========================================================================
  // 公开校验方法
  // ===========================================================================

  /// 校验图片文件
  ///
  /// 检查：文件存在、格式支持、Magic Bytes、大小限制
  Future<MediaValidationResult> validateImage(String localFilePath) {
    return _validateFile(
      localFilePath: localFilePath,
      maxSizeMb: config.maxImageSizeMb,
      supportedExtensions: imageExtensions,
      mediaType: 'image',
    );
  }

  /// 校验视频文件
  Future<MediaValidationResult> validateVideo(String localFilePath) {
    return _validateFile(
      localFilePath: localFilePath,
      maxSizeMb: config.maxVideoSizeMb,
      supportedExtensions: videoExtensions,
      mediaType: 'video',
    );
  }

  /// 校验音频文件
  Future<MediaValidationResult> validateAudio(String localFilePath) {
    return _validateFile(
      localFilePath: localFilePath,
      maxSizeMb: config.maxFileSizeMb,
      supportedExtensions: audioExtensions,
      mediaType: 'audio',
    );
  }

  /// 校验普通文件（不限制格式）
  Future<MediaValidationResult> validateFile(String localFilePath) {
    return _validateFile(
      localFilePath: localFilePath,
      maxSizeMb: config.maxFileSizeMb,
      supportedExtensions: null,
      mediaType: 'file',
    );
  }

  // ===========================================================================
  // 内部校验逻辑
  // ===========================================================================

  /// 通用文件校验
  ///
  /// 校验步骤：
  /// 1. 文件是否存在
  /// 2. 扩展名是否支持
  /// 3. Magic Bytes 验证（内容与扩展名是否匹配）
  /// 4. 文件大小是否超限
  Future<MediaValidationResult> _validateFile({
    required String localFilePath,
    required int maxSizeMb,
    List<String>? supportedExtensions,
    required String mediaType,
  }) async {
    final file = File(localFilePath);

    // 1. 检查文件是否存在
    if (!await file.exists()) {
      return MediaValidationResult.failure(
        '文件不存在',
        UploadFailureType.fileNotFound,
      );
    }

    // 2. 检查文件扩展名
    final ext = localFilePath.split('.').last.toLowerCase();
    if (supportedExtensions != null) {
      final isSupported = supportedExtensions.any(
        (supported) => supported.toLowerCase().endsWith(ext),
      );
      if (!isSupported) {
        return MediaValidationResult.failure(
          '不支持的$mediaType格式: $ext',
          UploadFailureType.unsupportedFormat,
        );
      }
    }

    // 3. Magic Bytes 验证（检测文件真实类型）
    if (!kIsWeb) {
      final magicBytesResult = await _validateMagicBytes(file, ext, mediaType);
      if (!magicBytesResult.isValid) {
        return magicBytesResult;
      }
    }

    // 4. 检查文件大小
    final fileSize = await file.length();
    final maxSize = maxSizeMb * 1024 * 1024;
    if (fileSize > maxSize) {
      final sizeMb = (fileSize / 1024 / 1024).toStringAsFixed(1);
      return MediaValidationResult.failure(
        '文件过大 (${sizeMb}MB)，最大支持 ${maxSizeMb}MB',
        UploadFailureType.fileTooLarge,
      );
    }

    return MediaValidationResult.success();
  }

  /// 验证文件 Magic Bytes
  ///
  /// 读取文件头部 16 字节，检测真实文件类型
  Future<MediaValidationResult> _validateMagicBytes(
    File file,
    String extension,
    String mediaType,
  ) async {
    try {
      // 读取文件头部
      final stream = file.openRead(0, 16);
      final bytes = await stream.first;

      if (bytes.isEmpty) {
        return MediaValidationResult.failure(
          '文件为空',
          UploadFailureType.unsupportedFormat,
        );
      }

      // 检测真实 MIME 类型
      final detectedMime = FileMagicBytes.detectMimeType(bytes);
      if (detectedMime == null) {
        // 无法识别的格式，允许通过（可能是新格式）
        debugPrint('[MediaValidator] 无法识别文件类型，允许上传: $extension');
        return MediaValidationResult.success();
      }

      // 获取扩展名对应的期望 MIME 类型
      final expectedMime = FileMagicBytes.getMimeType(file.path);

      // 检查是否匹配
      if (!_isMimeTypeCompatible(expectedMime, detectedMime)) {
        debugPrint('[MediaValidator] 文件类型不匹配！ 扩展名: .$extension ($expectedMime), 实际: $detectedMime');
        return MediaValidationResult.failure(
          '文件内容与扩展名不匹配',
          UploadFailureType.contentMismatch,
        );
      }

      debugPrint('[MediaValidator] Magic Bytes 验证通过: $detectedMime');
      return MediaValidationResult.success();
    } catch (e) {
      debugPrint('[MediaValidator] Magic Bytes 验证异常: $e');
      // 验证失败不阻止上传，只记录警告
      return MediaValidationResult.success();
    }
  }

  /// 检查两个 MIME 类型是否兼容
  bool _isMimeTypeCompatible(String expected, String detected) {
    // 完全匹配
    if (expected == detected) return true;

    // Office 文档是 ZIP 格式
    if (expected.contains('officedocument') && detected == 'application/zip') {
      return true;
    }

    // M4A 音频实际是 MP4 容器
    if (expected == 'audio/x-m4a' && detected == 'video/mp4') {
      return true;
    }

    // MOV 和 MP4 可以互换
    if ((expected == 'video/quicktime' || expected == 'video/mp4') &&
        (detected == 'video/quicktime' || detected == 'video/mp4')) {
      return true;
    }

    // 同类型媒体（如 image/* 匹配 image/*）
    final expectedType = expected.split('/').first;
    final detectedType = detected.split('/').first;
    if (expectedType == detectedType) {
      return true;
    }

    return false;
  }
}
