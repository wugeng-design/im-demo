/// IM 模块日志便捷函数
///
/// 提供简洁的日志 API，自动集成文件持久化
///
/// 使用方式：
/// ```dart
/// imLog('连接成功', tag: ImLogTags.connection);
/// imLogInfo('收到消息', tag: ImLogTags.message);
/// imLogWarn('连接不稳定', tag: ImLogTags.connection);
/// imLogError('发送失败', error: e, tag: ImLogTags.message);
/// ```
library;

import 'im_file_logger.dart';
import 'im_log_tags.dart';

export 'im_file_logger.dart' show ImLogLevel, ImFileLogger;
export 'im_log_tags.dart';

/// Debug 级别日志
///
/// 用于开发调试信息，生产环境不会输出到控制台
void imLog(String message, {String? tag}) {
  final t = tag ?? ImLogTags.im;
  ImFileLogger.debug(message, tag: t);
}

/// Info 级别日志
///
/// 用于记录重要的业务事件
void imLogInfo(String message, {String? tag}) {
  final t = tag ?? ImLogTags.im;
  ImFileLogger.info(message, tag: t);
}

/// Warning 级别日志
///
/// 用于记录潜在问题，但不影响主功能
void imLogWarn(String message, {String? tag, Object? error}) {
  final t = tag ?? ImLogTags.im;
  ImFileLogger.warning(message, tag: t, error: error);
}

/// Error 级别日志
///
/// 用于记录错误，会立即刷新到文件
void imLogError(
  String message, {
  String? tag,
  Object? error,
  StackTrace? stackTrace,
}) {
  final t = tag ?? ImLogTags.im;
  ImFileLogger.error(message, tag: t, error: error, stackTrace: stackTrace);
}

/// 性能日志
///
/// 用于记录性能相关信息
void imLogPerf(String message) {
  ImFileLogger.debug(message, tag: ImLogTags.perf);
}

/// 连接日志
///
/// 用于记录连接相关信息
void imLogConnection(String message, {ImLogLevel level = ImLogLevel.debug}) {
  ImFileLogger.log(message, tag: ImLogTags.connection, level: level);
}

/// 消息日志
///
/// 用于记录消息收发相关信息
void imLogMessage(String message, {ImLogLevel level = ImLogLevel.debug}) {
  ImFileLogger.log(message, tag: ImLogTags.message, level: level);
}

/// 数据库日志
///
/// 用于记录数据库操作
void imLogDb(String message, {ImLogLevel level = ImLogLevel.debug}) {
  ImFileLogger.log(message, tag: ImLogTags.db, level: level);
}
