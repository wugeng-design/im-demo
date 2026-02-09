/// EXIF 数据处理服务
///
/// 提供图片 EXIF 元数据的检测和剥离功能
/// 用于隐私保护（移除 GPS 位置等敏感信息）
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, Uint8List, debugPrint;

/// 格式化字节数
String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
}

/// EXIF 数据处理器
///
/// 使用示例：
/// ```dart
/// // 检查是否有 EXIF 数据
/// final hasExif = await ExifProcessor.hasExifData(imageFile);
///
/// // 剥离 EXIF 数据
/// if (hasExif) {
///   final cleanFile = await ExifProcessor.stripExifData(imageFile);
/// }
/// ```
class ExifProcessor {
  /// 敏感 EXIF 字段列表
  static const List<String> sensitiveFields = [
    'GPSLatitude', 'GPSLongitude', 'GPSAltitude',
    'GPSTimeStamp', 'GPSDateStamp',
    'Make', 'Model', 'Software',
    'Artist', 'Copyright', 'ImageDescription',
    'CameraSerialNumber', 'LensSerialNumber',
  ];

  /// 检查 JPEG 文件是否包含 EXIF 数据
  static Future<bool> hasExifData(File file) async {
    if (kIsWeb) {
      debugPrint('[ExifProcessor] Web 平台不支持 EXIF 检测');
      return false;
    }

    try {
      final bytes = await file.openRead(0, 12).first;

      // 检查 JPEG 标记 (0xFFD8) + APP1 标记 (0xFFE1)
      if (bytes.length >= 4 &&
          bytes[0] == 0xFF && bytes[1] == 0xD8 &&
          bytes[2] == 0xFF && bytes[3] == 0xE1) {
        debugPrint('[ExifProcessor] 检测到 EXIF 数据');
        return true;
      }

      debugPrint('[ExifProcessor] 未检测到 EXIF 数据');
      return false;
    } catch (e) {
      debugPrint('[ExifProcessor] EXIF 检测失败: $e');
      return false;
    }
  }

  /// 剥离 JPEG 文件的 EXIF 数据
  ///
  /// [inputFile] 输入文件
  /// [outputPath] 输出路径（可选，默认生成新文件）
  ///
  /// 返回处理后的文件
  static Future<File> stripExifData(
    File inputFile, {
    String? outputPath,
  }) async {
    if (kIsWeb) {
      debugPrint('[ExifProcessor] Web 平台不支持 EXIF 剥离');
      return inputFile;
    }

    try {
      debugPrint('[ExifProcessor] 开始剥离 EXIF 数据');

      final bytes = await inputFile.readAsBytes();
      if (bytes.length < 4) {
        debugPrint('[ExifProcessor] 文件太小');
        return inputFile;
      }

      // 检查是否为 JPEG
      if (bytes[0] != 0xFF || bytes[1] != 0xD8) {
        debugPrint('[ExifProcessor] 非 JPEG 文件，跳过');
        return inputFile;
      }

      final cleanedBytes = _removeExifFromJpeg(bytes);

      // 写入文件
      final outputFile = File(outputPath ?? '${inputFile.path}.clean.jpg');
      await outputFile.writeAsBytes(cleanedBytes);

      final saved = bytes.length - cleanedBytes.length;
      debugPrint('[ExifProcessor] 完成，节省 ${_formatBytes(saved)}');

      return outputFile;
    } catch (e) {
      debugPrint('[ExifProcessor] EXIF 剥离失败: $e');
      return inputFile;
    }
  }

  /// 从 JPEG 字节中移除 EXIF
  static Uint8List _removeExifFromJpeg(Uint8List bytes) {
    final result = <int>[];

    // 添加 SOI 标记
    result.add(0xFF);
    result.add(0xD8);

    int pos = 2;
    bool foundImageData = false;

    while (pos < bytes.length - 1 && !foundImageData) {
      if (bytes[pos] != 0xFF) break;

      final marker = bytes[pos + 1];

      // SOS (图像数据开始)
      if (marker == 0xDA) {
        foundImageData = true;
        result.addAll(bytes.sublist(pos));
        break;
      }

      // APP1 (EXIF) - 跳过
      if (marker == 0xE1) {
        if (pos + 3 < bytes.length) {
          final segmentLength = (bytes[pos + 2] << 8) | bytes[pos + 3];
          pos += 2 + segmentLength;
        } else {
          break;
        }
        continue;
      }

      // 其他段 - 保留
      if ((marker >= 0xE0 && marker <= 0xEF) ||
          marker == 0xDB || marker == 0xC0 ||
          marker == 0xC4 || marker == 0xDD) {
        if (pos + 3 < bytes.length) {
          final segmentLength = (bytes[pos + 2] << 8) | bytes[pos + 3];
          result.addAll(bytes.sublist(pos, pos + 2 + segmentLength));
          pos += 2 + segmentLength;
        } else {
          break;
        }
      } else {
        result.add(bytes[pos]);
        result.add(bytes[pos + 1]);
        pos += 2;
      }
    }

    return Uint8List.fromList(result);
  }

  /// 获取 EXIF 处理建议
  static Future<ExifRecommendation> getRecommendation(File file) async {
    final fileName = file.path.split('/').last.toLowerCase();

    // 只处理 JPEG 文件
    if (!fileName.endsWith('.jpg') && !fileName.endsWith('.jpeg')) {
      return const ExifRecommendation(
        shouldProcess: false,
        reason: '非 JPEG 文件，不包含 EXIF',
        hasExif: false,
      );
    }

    final hasExif = await hasExifData(file);

    if (hasExif) {
      return const ExifRecommendation(
        shouldProcess: true,
        reason: '检测到 EXIF 数据，建议剥离以保护隐私',
        hasExif: true,
      );
    }

    return const ExifRecommendation(
      shouldProcess: false,
      reason: '未检测到 EXIF 数据',
      hasExif: false,
    );
  }
}

/// EXIF 处理建议
class ExifRecommendation {
  final bool shouldProcess;
  final String reason;
  final bool hasExif;

  const ExifRecommendation({
    required this.shouldProcess,
    required this.reason,
    required this.hasExif,
  });

  @override
  String toString() =>
      'ExifRecommendation(process: $shouldProcess, hasExif: $hasExif)';
}

/// EXIF 处理配置
class ExifProcessorConfig {
  final bool autoStrip;
  final bool showWarning;

  const ExifProcessorConfig({
    this.autoStrip = true,
    this.showWarning = true,
  });

  /// 默认配置（自动剥离 EXIF）
  static const ExifProcessorConfig defaultConfig = ExifProcessorConfig();

  /// 禁用配置
  static const ExifProcessorConfig disabled = ExifProcessorConfig(
    autoStrip: false,
    showWarning: false,
  );
}
