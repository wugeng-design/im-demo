/// IM 日志模块
///
/// 统一导出所有日志相关 API
///
/// 使用方式：
/// ```dart
/// import 'package:im_demo/sdk/logging/logging.dart';
///
/// // 初始化（在 IM 模块启动时调用一次）
/// await ImFileLogger.init();
///
/// // 使用便捷函数记录日志
/// imLog('连接成功', tag: ImLogTags.connection);
/// imLogError('发送失败', error: e);
///
/// // 导出日志（用于分享/诊断）
/// final logsPath = await ImFileLogger.export();
/// ```
library;

export 'im_file_logger.dart';
export 'im_log_tags.dart';
export 'im_logger.dart';
