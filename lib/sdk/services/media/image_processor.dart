/// 图片处理服务
///
/// 功能：
/// - 图片压缩（控制文件大小和质量）
/// - 缩略图生成（用于预览）
/// - 获取图片尺寸信息
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Uint8List, debugPrint;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 图片处理结果
class ImageProcessResult {
  /// 处理后的图片数据
  final Uint8List data;

  /// 图片宽度
  final int width;

  /// 图片高度
  final int height;

  /// 文件大小（字节）
  final int size;

  /// MIME 类型
  final String mimeType;

  const ImageProcessResult({
    required this.data,
    required this.width,
    required this.height,
    required this.size,
    required this.mimeType,
  });

  /// 宽高比
  double get aspectRatio => height > 0 ? width / height : 1.0;

  @override
  String toString() =>
      'ImageProcessResult(${width}x$height, ${(size / 1024).toStringAsFixed(1)}KB)';
}

/// 图片处理配置
class ImageProcessConfig {
  /// 压缩质量 (0-100)
  final int compressionQuality;

  /// 最大宽度
  final int maxWidth;

  /// 最大高度
  final int maxHeight;

  /// 缩略图最大尺寸
  final int thumbnailMaxSize;

  /// 缩略图质量
  final int thumbnailQuality;

  const ImageProcessConfig({
    this.compressionQuality = 85,
    this.maxWidth = 1920,
    this.maxHeight = 1920,
    this.thumbnailMaxSize = 200,
    this.thumbnailQuality = 70,
  });

  static const defaultConfig = ImageProcessConfig();
}

/// 图片处理服务
class ImageProcessor {
  final ImageProcessConfig config;

  ImageProcessor({this.config = ImageProcessConfig.defaultConfig});

  /// 压缩图片
  ///
  /// [inputFile] 输入文件
  /// [quality] 压缩质量 (0-100)，默认使用配置值
  /// [maxWidth] 最大宽度，null 表示使用配置值
  /// [maxHeight] 最大高度，null 表示使用配置值
  Future<ImageProcessResult?> compress({
    required File inputFile,
    int? quality,
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      final inputBytes = await inputFile.readAsBytes();
      return await compressBytes(
        data: inputBytes,
        filename: path.basename(inputFile.path),
        quality: quality,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      );
    } catch (e) {
      debugPrint('[ImageProcessor] 压缩失败: $e');
      return null;
    }
  }

  /// 压缩图片（从字节数组）
  Future<ImageProcessResult?> compressBytes({
    required Uint8List data,
    required String filename,
    int? quality,
    int? maxWidth,
    int? maxHeight,
  }) async {
    try {
      final effectiveQuality = quality ?? config.compressionQuality;
      final effectiveMaxWidth = maxWidth ?? config.maxWidth;
      final effectiveMaxHeight = maxHeight ?? config.maxHeight;
      final format = _getCompressFormat(filename);
      final mimeType = _getMimeType(format);

      debugPrint('[ImageProcessor] 压缩 $filename (${(data.length / 1024).toStringAsFixed(1)}KB, quality: $effectiveQuality)');

      // 使用 flutter_image_compress
      final result = await FlutterImageCompress.compressWithList(
        data,
        minWidth: effectiveMaxWidth,
        minHeight: effectiveMaxHeight,
        quality: effectiveQuality,
        format: format,
      );

      // 获取图片尺寸
      final dimensions = await _getImageDimensions(result);

      debugPrint('[ImageProcessor] 压缩完成 ${dimensions.$1}x${dimensions.$2} → ${(result.length / 1024).toStringAsFixed(1)}KB');

      return ImageProcessResult(
        data: result,
        width: dimensions.$1,
        height: dimensions.$2,
        size: result.length,
        mimeType: mimeType,
      );
    } catch (e) {
      debugPrint('[ImageProcessor] 压缩失败: $e');
      return null;
    }
  }

  /// 生成缩略图
  Future<ImageProcessResult?> generateThumbnail({
    required File inputFile,
    int? maxSize,
  }) async {
    try {
      final inputBytes = await inputFile.readAsBytes();
      return await generateThumbnailBytes(
        data: inputBytes,
        filename: path.basename(inputFile.path),
        maxSize: maxSize,
      );
    } catch (e) {
      debugPrint('[ImageProcessor] 生成缩略图失败: $e');
      return null;
    }
  }

  /// 生成缩略图（从字节数组）
  Future<ImageProcessResult?> generateThumbnailBytes({
    required Uint8List data,
    required String filename,
    int? maxSize,
  }) async {
    try {
      final effectiveMaxSize = maxSize ?? config.thumbnailMaxSize;
      final format = _getCompressFormat(filename);
      final mimeType = _getMimeType(format);

      debugPrint('[ImageProcessor] 生成缩略图 $filename (max: $effectiveMaxSize)');

      // 使用较低质量生成缩略图
      final result = await FlutterImageCompress.compressWithList(
        data,
        minWidth: effectiveMaxSize,
        minHeight: effectiveMaxSize,
        quality: config.thumbnailQuality,
        format: format,
      );

      // 获取图片尺寸
      final dimensions = await _getImageDimensions(result);

      debugPrint('[ImageProcessor] 缩略图完成 ${dimensions.$1}x${dimensions.$2} → ${(result.length / 1024).toStringAsFixed(1)}KB');

      return ImageProcessResult(
        data: result,
        width: dimensions.$1,
        height: dimensions.$2,
        size: result.length,
        mimeType: mimeType,
      );
    } catch (e) {
      debugPrint('[ImageProcessor] 生成缩略图失败: $e');
      return null;
    }
  }

  /// 获取图片信息（不压缩）
  Future<ImageProcessResult?> getImageInfo(File inputFile) async {
    try {
      final data = await inputFile.readAsBytes();
      final dimensions = await _getImageDimensions(data);
      final format = _getCompressFormat(inputFile.path);

      return ImageProcessResult(
        data: data,
        width: dimensions.$1,
        height: dimensions.$2,
        size: data.length,
        mimeType: _getMimeType(format),
      );
    } catch (e) {
      debugPrint('[ImageProcessor] 获取图片信息失败: $e');
      return null;
    }
  }

  /// 保存到临时文件
  Future<File?> saveToTempFile(Uint8List data, String filename) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempPath = '${tempDir.path}/img_${timestamp}_$filename';
      final file = File(tempPath);
      await file.writeAsBytes(data);
      return file;
    } catch (e) {
      debugPrint('[ImageProcessor] 保存临时文件失败: $e');
      return null;
    }
  }

  /// 获取图片尺寸
  Future<(int, int)> getImageDimensions(File file) async {
    try {
      final data = await file.readAsBytes();
      return await _getImageDimensions(data);
    } catch (e) {
      debugPrint('[ImageProcessor] 无法读取图片文件: $e');
      return (0, 0);
    }
  }

  /// 获取压缩格式
  CompressFormat _getCompressFormat(String filename) {
    final ext = path.extension(filename).toLowerCase();
    switch (ext) {
      case '.png':
        return CompressFormat.png;
      case '.webp':
        return CompressFormat.webp;
      case '.heic':
        return CompressFormat.heic;
      default:
        return CompressFormat.jpeg;
    }
  }

  /// 获取 MIME 类型
  String _getMimeType(CompressFormat format) {
    switch (format) {
      case CompressFormat.png:
        return 'image/png';
      case CompressFormat.webp:
        return 'image/webp';
      case CompressFormat.heic:
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  /// 获取图片尺寸（内部方法）
  Future<(int, int)> _getImageDimensions(Uint8List data) async {
    try {
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final width = image.width;
      final height = image.height;
      image.dispose();
      return (width, height);
    } catch (e) {
      debugPrint('[ImageProcessor] 无法获取图片尺寸: $e');
      return (0, 0);
    }
  }
}
