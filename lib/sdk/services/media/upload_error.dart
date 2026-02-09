/// 上传错误类型和重试机制
///
/// 功能：
/// - 错误分类（可重试/不可重试）
/// - 错误消息
/// - 重试策略
library;

/// 上传错误类型
enum UploadErrorType {
  /// 网络连接错误（可重试）
  networkError,

  /// 服务器错误（可重试）
  serverError,

  /// 超时（可重试）
  timeout,

  /// 文件不存在（不可重试）
  fileNotFound,

  /// 文件格式不支持（不可重试）
  unsupportedFormat,

  /// 文件太大（不可重试）
  fileTooLarge,

  /// 权限被拒绝（不可重试）
  permissionDenied,

  /// 服务不可用（可重试）
  serviceUnavailable,

  /// 未知错误
  unknown,
}

/// 上传错误
class UploadError implements Exception {
  /// 错误类型
  final UploadErrorType type;

  /// 错误消息
  final String message;

  /// 原始异常
  final Object? originalError;

  /// HTTP 状态码
  final int? statusCode;

  const UploadError({
    required this.type,
    required this.message,
    this.originalError,
    this.statusCode,
  });

  /// 是否可重试
  bool get isRetryable {
    switch (type) {
      case UploadErrorType.networkError:
      case UploadErrorType.serverError:
      case UploadErrorType.timeout:
      case UploadErrorType.serviceUnavailable:
        return true;
      case UploadErrorType.fileNotFound:
      case UploadErrorType.unsupportedFormat:
      case UploadErrorType.fileTooLarge:
      case UploadErrorType.permissionDenied:
        return false;
      case UploadErrorType.unknown:
        return true; // 未知错误默认可重试
    }
  }

  /// 用户友好的错误消息
  String get userMessage {
    switch (type) {
      case UploadErrorType.networkError:
        return '网络连接失败，请检查网络后重试';
      case UploadErrorType.serverError:
        return '服务器错误，请稍后重试';
      case UploadErrorType.timeout:
        return '上传超时，请稍后重试';
      case UploadErrorType.fileNotFound:
        return '文件不存在';
      case UploadErrorType.unsupportedFormat:
        return '不支持的文件格式';
      case UploadErrorType.fileTooLarge:
        return '文件太大';
      case UploadErrorType.permissionDenied:
        return '没有权限上传此文件';
      case UploadErrorType.serviceUnavailable:
        return '服务暂时不可用，请稍后重试';
      case UploadErrorType.unknown:
        return '上传失败，请重试';
    }
  }

  @override
  String toString() => 'UploadError($type): $message';

  /// 从异常创建 UploadError
  factory UploadError.fromException(Object error) {
    if (error is UploadError) return error;

    final errorString = error.toString().toLowerCase();

    // 网络相关错误
    if (errorString.contains('socket') ||
        errorString.contains('connection') ||
        errorString.contains('network')) {
      return UploadError(
        type: UploadErrorType.networkError,
        message: '网络连接失败',
        originalError: error,
      );
    }

    // 超时
    if (errorString.contains('timeout') || errorString.contains('timed out')) {
      return UploadError(
        type: UploadErrorType.timeout,
        message: '请求超时',
        originalError: error,
      );
    }

    // 文件不存在
    if (errorString.contains('not found') ||
        errorString.contains('no such file') ||
        errorString.contains('path not found')) {
      return UploadError(
        type: UploadErrorType.fileNotFound,
        message: '文件不存在',
        originalError: error,
      );
    }

    // 权限错误
    if (errorString.contains('permission') ||
        errorString.contains('access denied')) {
      return UploadError(
        type: UploadErrorType.permissionDenied,
        message: '权限被拒绝',
        originalError: error,
      );
    }

    // 未知错误
    return UploadError(
      type: UploadErrorType.unknown,
      message: error.toString(),
      originalError: error,
    );
  }

  /// 从 HTTP 状态码创建 UploadError
  factory UploadError.fromHttpStatus(int statusCode, [String? body]) {
    UploadErrorType type;
    String message;

    if (statusCode >= 500) {
      type = UploadErrorType.serverError;
      message = '服务器错误 ($statusCode)';
    } else if (statusCode == 413) {
      type = UploadErrorType.fileTooLarge;
      message = '文件太大';
    } else if (statusCode == 415) {
      type = UploadErrorType.unsupportedFormat;
      message = '不支持的文件格式';
    } else if (statusCode == 403) {
      type = UploadErrorType.permissionDenied;
      message = '权限被拒绝';
    } else if (statusCode == 404) {
      type = UploadErrorType.serviceUnavailable;
      message = '上传服务不可用';
    } else if (statusCode == 503) {
      type = UploadErrorType.serviceUnavailable;
      message = '服务暂时不可用';
    } else {
      type = UploadErrorType.unknown;
      message = 'HTTP 错误 ($statusCode)';
    }

    return UploadError(
      type: type,
      message: message,
      statusCode: statusCode,
      originalError: body,
    );
  }
}

/// 重试配置
class RetryConfig {
  /// 最大重试次数
  final int maxRetries;

  /// 初始延迟
  final Duration initialDelay;

  /// 最大延迟
  final Duration maxDelay;

  /// 延迟乘数
  final double backoffMultiplier;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
  });

  static const defaultConfig = RetryConfig();

  /// 计算第 n 次重试的延迟时间
  Duration getDelayForAttempt(int attempt) {
    if (attempt <= 0) return Duration.zero;

    var delay = initialDelay;
    for (var i = 1; i < attempt; i++) {
      delay = Duration(
        milliseconds: (delay.inMilliseconds * backoffMultiplier).round(),
      );
      if (delay > maxDelay) {
        delay = maxDelay;
        break;
      }
    }
    return delay;
  }
}

/// 带重试的执行器
class RetryExecutor {
  final RetryConfig config;

  RetryExecutor({this.config = RetryConfig.defaultConfig});

  /// 执行带重试的操作
  ///
  /// [operation] 要执行的操作
  /// [shouldRetry] 可选的自定义重试判断函数
  /// [onRetry] 每次重试前的回调
  Future<T> execute<T>(
    Future<T> Function() operation, {
    bool Function(Object error)? shouldRetry,
    void Function(int attempt, Duration delay, Object error)? onRetry,
  }) async {
    var attempt = 0;

    while (true) {
      attempt++;
      try {
        return await operation();
      } catch (e) {
        // 检查是否应该重试
        final error = e is UploadError ? e : UploadError.fromException(e);
        final canRetry = shouldRetry?.call(e) ?? error.isRetryable;

        if (!canRetry || attempt >= config.maxRetries) {
          rethrow;
        }

        // 计算延迟
        final delay = config.getDelayForAttempt(attempt);

        // 回调
        onRetry?.call(attempt, delay, e);

        // 等待后重试
        await Future.delayed(delay);
      }
    }
  }
}
