/// IM 模块文件日志器
///
/// 独立的日志文件持久化
/// - 单独的日志文件目录 (logs/im/)
/// - 按日期滚动 (im_YYYY-MM-DD.log)
/// - 自动清理过期日志 (7天)
/// - 异步队列写入，不阻塞主线程
/// - 支持导出
///
/// 使用方式：
/// ```dart
/// // 初始化（在 IM 模块初始化时调用）
/// await ImFileLogger.init();
///
/// // 写日志（完全异步，不阻塞）
/// ImFileLogger.log('收到消息', tag: 'MAM');
/// ImFileLogger.error('发送失败', error: e);
/// ```
library;

import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint, kReleaseMode;
import 'package:path_provider/path_provider.dart';

/// IM 文件日志级别
enum ImLogLevel {
  debug,
  info,
  warning,
  error,
}

/// 日志条目
class _LogEntry {
  final String message;
  final String tag;
  final ImLogLevel level;
  final Object? error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  _LogEntry({
    required this.message,
    required this.tag,
    required this.level,
    this.error,
    this.stackTrace,
    required this.timestamp,
  });
}

/// IM 文件日志器
///
/// 使用异步队列处理日志写入，确保：
/// 1. 写入操作不阻塞主线程
/// 2. 避免并发写入导致的 StreamSink 冲突
/// 3. 批量写入提高性能
class ImFileLogger {
  ImFileLogger._();

  static bool _isInitialized = false;
  static String? _logsPath;
  static IOSink? _currentSink;
  static String? _currentDate;

  /// 写入队列
  static final Queue<_LogEntry> _queue = Queue<_LogEntry>();

  /// 是否正在处理队列
  static bool _isProcessing = false;

  /// 队列处理定时器（用于批量写入）
  static Timer? _flushTimer;

  /// 批量写入间隔（毫秒）
  static const int _batchIntervalMs = 100;

  /// 日志保留天数
  static const int _retentionDays = 7;

  /// 是否已初始化
  static bool get isInitialized => _isInitialized;

  /// 获取日志目录路径
  static String? get logsPath => _logsPath;

  /// 初始化日志器
  ///
  /// 应在 IM 模块初始化时调用
  static Future<void> init() async {
    if (_isInitialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      _logsPath = '${appDir.path}/logs/im';

      // 创建日志目录
      final dir = Directory(_logsPath!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      _isInitialized = true;

      // 后台清理过期日志
      _cleanExpiredLogs();

      if (!kReleaseMode) {
        debugPrint('[ImFileLogger] initialized: $_logsPath');
      }
    } catch (e) {
      if (!kReleaseMode) {
        debugPrint('[ImFileLogger] init failed: $e');
      }
    }
  }

  /// 写入日志
  ///
  /// 完全异步，不阻塞调用线程
  static void log(
    String message, {
    String tag = 'IM',
    ImLogLevel level = ImLogLevel.debug,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final now = DateTime.now();

    // 控制台输出（debug 模式）
    if (!kReleaseMode) {
      final levelStr = _levelToString(level);
      debugPrint('[$tag] [$levelStr] $message');
      if (error != null) {
        debugPrint('  Error: $error');
      }
    }

    // 加入队列（异步写入文件）
    _enqueue(_LogEntry(
      message: message,
      tag: tag,
      level: level,
      error: error,
      stackTrace: stackTrace,
      timestamp: now,
    ));
  }

  /// 加入写入队列
  static void _enqueue(_LogEntry entry) {
    if (!_isInitialized || _logsPath == null) return;

    _queue.add(entry);

    // 启动定时器，批量处理队列
    _flushTimer ??= Timer(Duration(milliseconds: _batchIntervalMs), _processQueue);
  }

  /// 处理写入队列
  static Future<void> _processQueue() async {
    _flushTimer = null;

    // 防止并发处理
    if (_isProcessing || _queue.isEmpty) return;
    _isProcessing = true;

    try {
      // 取出所有待写入的日志
      final entries = <_LogEntry>[];
      while (_queue.isNotEmpty) {
        entries.add(_queue.removeFirst());
      }

      // 批量写入
      await _writeBatch(entries);
    } finally {
      _isProcessing = false;

      // 如果队列中又有新日志，继续处理
      if (_queue.isNotEmpty) {
        _flushTimer = Timer(Duration(milliseconds: _batchIntervalMs), _processQueue);
      }
    }
  }

  /// 批量写入日志
  static Future<void> _writeBatch(List<_LogEntry> entries) async {
    if (entries.isEmpty || _logsPath == null) return;

    try {
      // 按日期分组
      final byDate = <String, List<_LogEntry>>{};
      for (final entry in entries) {
        final dateStr = _formatDate(entry.timestamp);
        byDate.putIfAbsent(dateStr, () => []).add(entry);
      }

      // 写入每个日期的日志
      for (final dateStr in byDate.keys) {
        final dateEntries = byDate[dateStr]!;

        // 日期变化时切换文件
        if (_currentDate != dateStr || _currentSink == null) {
          await _currentSink?.flush();
          await _currentSink?.close();

          final filePath = '$_logsPath/im_$dateStr.log';
          final file = File(filePath);
          _currentSink = file.openWrite(mode: FileMode.append);
          _currentDate = dateStr;
        }

        // 格式化并写入所有日志
        final buffer = StringBuffer();
        bool hasError = false;

        for (final entry in dateEntries) {
          final timestamp = _formatTimestamp(entry.timestamp);
          final levelStr = _levelToString(entry.level);
          buffer.writeln('[$timestamp] [${entry.tag}] [$levelStr] ${entry.message}');
          if (entry.error != null) {
            buffer.writeln('  Error: ${entry.error}');
          }
          if (entry.stackTrace != null) {
            buffer.writeln('  StackTrace: ${entry.stackTrace}');
          }
          if (entry.level == ImLogLevel.error) {
            hasError = true;
          }
        }

        _currentSink?.write(buffer.toString());

        // 有 Error 级别日志时立即刷新
        if (hasError) {
          await _currentSink?.flush();
        }
      }
    } catch (e) {
      // 静默失败，不影响主功能
      if (!kReleaseMode) {
        debugPrint('[ImFileLogger] batch write failed: $e');
      }
    }
  }

  /// Debug 日志
  static void debug(String message, {String tag = 'IM'}) {
    log(message, tag: tag, level: ImLogLevel.debug);
  }

  /// Info 日志
  static void info(String message, {String tag = 'IM'}) {
    log(message, tag: tag, level: ImLogLevel.info);
  }

  /// Warning 日志
  static void warning(String message, {String tag = 'IM', Object? error}) {
    log(message, tag: tag, level: ImLogLevel.warning, error: error);
  }

  /// Error 日志
  static void error(String message, {String tag = 'IM', Object? error, StackTrace? stackTrace}) {
    log(message, tag: tag, level: ImLogLevel.error, error: error, stackTrace: stackTrace);
  }

  /// 刷新缓冲区
  ///
  /// 立即处理队列中的所有日志并刷新到文件
  static Future<void> flush() async {
    // 取消定时器，立即处理
    _flushTimer?.cancel();
    _flushTimer = null;

    // 处理队列
    if (_queue.isNotEmpty && !_isProcessing) {
      await _processQueue();
    }

    // 刷新文件缓冲区
    await _currentSink?.flush();
  }

  /// 关闭日志器
  ///
  /// 先刷新所有待写入的日志，然后关闭文件
  static Future<void> close() async {
    // 取消定时器
    _flushTimer?.cancel();
    _flushTimer = null;

    // 处理剩余队列
    if (_queue.isNotEmpty && !_isProcessing) {
      _isProcessing = true;
      try {
        final entries = <_LogEntry>[];
        while (_queue.isNotEmpty) {
          entries.add(_queue.removeFirst());
        }
        await _writeBatch(entries);
      } finally {
        _isProcessing = false;
      }
    }

    // 关闭文件
    await _currentSink?.flush();
    await _currentSink?.close();
    _currentSink = null;
    _currentDate = null;
  }

  /// 清理过期日志
  static Future<int> _cleanExpiredLogs() async {
    if (_logsPath == null) return 0;

    try {
      final dir = Directory(_logsPath!);
      if (!await dir.exists()) return 0;

      final now = DateTime.now();
      final expiryDate = now.subtract(Duration(days: _retentionDays));
      int deletedCount = 0;

      await for (final file in dir.list()) {
        if (file is File && file.path.endsWith('.log')) {
          try {
            final stat = await file.stat();
            if (stat.modified.isBefore(expiryDate)) {
              await file.delete();
              deletedCount++;
              if (!kReleaseMode) {
                debugPrint('[ImFileLogger] deleted ${file.path}');
              }
            }
          } catch (_) {}
        }
      }

      return deletedCount;
    } catch (e) {
      if (!kReleaseMode) {
        debugPrint('[ImFileLogger] cleanup failed: $e');
      }
      return 0;
    }
  }

  /// 获取所有日志文件
  static Future<List<File>> getLogFiles() async {
    if (_logsPath == null) return [];

    try {
      final dir = Directory(_logsPath!);
      if (!await dir.exists()) return [];

      final files = <File>[];
      await for (final file in dir.list()) {
        if (file is File && file.path.endsWith('.log')) {
          files.add(file);
        }
      }

      // 按日期排序（最新的在前）
      files.sort((a, b) => b.path.compareTo(a.path));
      return files;
    } catch (e) {
      return [];
    }
  }

  /// 导出日志（返回日志目录路径）
  static Future<String?> export() async {
    await flush();
    return _logsPath;
  }

  /// 格式化时间戳: YYYY-MM-DD HH:mm:ss.SSS
  static String _formatTimestamp(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    final ms = dt.millisecond.toString().padLeft(3, '0');
    return '$y-$m-$d $h:$min:$s.$ms';
  }

  /// 格式化日期: YYYY-MM-DD
  static String _formatDate(DateTime dt) {
    final y = dt.year.toString();
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _levelToString(ImLogLevel level) {
    switch (level) {
      case ImLogLevel.debug:
        return 'DEBUG';
      case ImLogLevel.info:
        return 'INFO';
      case ImLogLevel.warning:
        return 'WARN';
      case ImLogLevel.error:
        return 'ERROR';
    }
  }
}
