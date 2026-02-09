/// 文件缓存服务
///
/// 功能：
/// - 下载文件并缓存到本地
/// - 根据 URL 查找缓存文件
/// - LRU 清理过期缓存
library;

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 文件缓存配置
class FileCacheConfig {
  /// 最大缓存大小（字节）
  final int maxCacheSize;

  /// 缓存过期时间
  final Duration cacheExpiration;

  /// 缓存目录名
  final String cacheDir;

  const FileCacheConfig({
    this.maxCacheSize = 500 * 1024 * 1024, // 500MB
    this.cacheExpiration = const Duration(days: 30),
    this.cacheDir = 'media_cache',
  });

  static const defaultConfig = FileCacheConfig();
}

/// 下载进度回调
typedef ProgressCallback = void Function(double progress);

/// 文件缓存服务
class FileCacheService {
  final FileCacheConfig config;
  String? _cacheBasePath;

  FileCacheService({this.config = FileCacheConfig.defaultConfig});

  /// 获取缓存目录
  Future<String> _getCachePath() async {
    if (_cacheBasePath != null) return _cacheBasePath!;

    final appDir = await getApplicationDocumentsDirectory();
    _cacheBasePath = path.join(appDir.path, config.cacheDir);

    // 确保目录存在
    final dir = Directory(_cacheBasePath!);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return _cacheBasePath!;
  }

  /// 根据 URL 生成缓存文件名
  String _getCacheFileName(String url) {
    final hash = md5.convert(utf8.encode(url)).toString();
    final ext = path.extension(Uri.parse(url).path);
    return '$hash$ext';
  }

  /// 获取缓存文件路径
  Future<String?> getCachedFile(String url) async {
    try {
      final cachePath = await _getCachePath();
      final fileName = _getCacheFileName(url);
      final filePath = path.join(cachePath, fileName);

      final file = File(filePath);
      if (await file.exists()) {
        // 更新访问时间
        await file.setLastAccessed(DateTime.now());
        debugPrint('[FileCache] 缓存命中: $fileName');
        return filePath;
      }
    } catch (e) {
      debugPrint('[FileCache] 检查缓存失败: $e');
    }
    return null;
  }

  /// 下载文件并缓存
  ///
  /// [url] 文件 URL
  /// [onProgress] 下载进度回调
  /// [headers] 请求头
  Future<String?> downloadAndCache(
    String url, {
    ProgressCallback? onProgress,
    Map<String, String>? headers,
  }) async {
    try {
      // 先检查缓存
      final cachedPath = await getCachedFile(url);
      if (cachedPath != null) {
        onProgress?.call(1.0);
        return cachedPath;
      }

      debugPrint('[FileCache] 开始下载: $url');

      final cachePath = await _getCachePath();
      final fileName = _getCacheFileName(url);
      final filePath = path.join(cachePath, fileName);

      // 下载文件
      final request = http.Request('GET', Uri.parse(url));
      if (headers != null) {
        request.headers.addAll(headers);
      }

      final client = http.Client();
      try {
        final response = await client.send(request);

        if (response.statusCode != 200) {
          debugPrint('[FileCache] 下载失败: HTTP ${response.statusCode}');
          return null;
        }

        final contentLength = response.contentLength ?? 0;
        var receivedBytes = 0;
        final bytes = <int>[];

        await for (final chunk in response.stream) {
          bytes.addAll(chunk);
          receivedBytes += chunk.length;

          if (contentLength > 0) {
            onProgress?.call(receivedBytes / contentLength);
          }
        }

        // 保存到缓存
        final file = File(filePath);
        await file.writeAsBytes(bytes);

        debugPrint('[FileCache] 下载完成: $fileName (${(bytes.length / 1024).toStringAsFixed(1)}KB)');

        // 检查缓存大小
        _checkCacheSize();

        return filePath;
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('[FileCache] 下载失败: $e');
      return null;
    }
  }

  /// 保存数据到缓存
  Future<String?> saveToCache(String url, List<int> data) async {
    try {
      final cachePath = await _getCachePath();
      final fileName = _getCacheFileName(url);
      final filePath = path.join(cachePath, fileName);

      final file = File(filePath);
      await file.writeAsBytes(data);

      debugPrint('[FileCache] 已缓存: $fileName (${(data.length / 1024).toStringAsFixed(1)}KB)');

      return filePath;
    } catch (e) {
      debugPrint('[FileCache] 保存缓存失败: $e');
      return null;
    }
  }

  /// 删除缓存文件
  Future<bool> deleteCachedFile(String url) async {
    try {
      final cachePath = await _getCachePath();
      final fileName = _getCacheFileName(url);
      final filePath = path.join(cachePath, fileName);

      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('[FileCache] 已删除: $fileName');
        return true;
      }
    } catch (e) {
      debugPrint('[FileCache] 删除缓存失败: $e');
    }
    return false;
  }

  /// 清理过期缓存
  Future<int> cleanupExpiredFiles() async {
    try {
      final cachePath = await _getCachePath();
      final dir = Directory(cachePath);
      if (!await dir.exists()) return 0;

      final now = DateTime.now();
      var deletedCount = 0;

      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          final age = now.difference(stat.accessed);

          if (age > config.cacheExpiration) {
            await entity.delete();
            deletedCount++;
          }
        }
      }

      if (deletedCount > 0) {
        debugPrint('[FileCache] 清理过期文件: $deletedCount 个');
      }

      return deletedCount;
    } catch (e) {
      debugPrint('[FileCache] 清理过期文件失败: $e');
      return 0;
    }
  }

  /// 获取缓存大小
  Future<int> getCacheSize() async {
    try {
      final cachePath = await _getCachePath();
      final dir = Directory(cachePath);
      if (!await dir.exists()) return 0;

      var totalSize = 0;
      await for (final entity in dir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      debugPrint('[FileCache] 获取缓存大小失败: $e');
      return 0;
    }
  }

  /// 清空缓存
  Future<void> clearCache() async {
    try {
      final cachePath = await _getCachePath();
      final dir = Directory(cachePath);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
        debugPrint('[FileCache] 缓存已清空');
      }
    } catch (e) {
      debugPrint('[FileCache] 清空缓存失败: $e');
    }
  }

  /// 检查缓存大小，超限时清理
  Future<void> _checkCacheSize() async {
    try {
      final currentSize = await getCacheSize();
      if (currentSize > config.maxCacheSize) {
        debugPrint('[FileCache] 缓存超限 (${(currentSize / 1024 / 1024).toStringAsFixed(1)}MB)，开始清理');

        // 先清理过期文件
        await cleanupExpiredFiles();

        // 如果还是超限，按 LRU 清理
        final newSize = await getCacheSize();
        if (newSize > config.maxCacheSize) {
          await _lruCleanup();
        }
      }
    } catch (e) {
      debugPrint('[FileCache] 检查缓存大小失败: $e');
    }
  }

  /// LRU 清理（删除最久未访问的文件）
  Future<void> _lruCleanup() async {
    try {
      final cachePath = await _getCachePath();
      final dir = Directory(cachePath);
      if (!await dir.exists()) return;

      // 获取所有文件及其访问时间
      final files = <MapEntry<File, DateTime>>[];
      await for (final entity in dir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          files.add(MapEntry(entity, stat.accessed));
        }
      }

      // 按访问时间排序（最旧的在前）
      files.sort((a, b) => a.value.compareTo(b.value));

      // 删除最旧的文件，直到缓存大小低于阈值
      var currentSize = await getCacheSize();
      final targetSize = config.maxCacheSize * 0.8; // 目标清理到 80%

      for (final entry in files) {
        if (currentSize <= targetSize) break;

        final fileSize = await entry.key.length();
        await entry.key.delete();
        currentSize -= fileSize;

        debugPrint('[FileCache] LRU 删除: ${path.basename(entry.key.path)}');
      }
    } catch (e) {
      debugPrint('[FileCache] LRU 清理失败: $e');
    }
  }
}
