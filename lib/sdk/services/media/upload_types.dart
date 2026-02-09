/// 媒体上传相关类型定义
///
/// 包含：
/// - HTTP 上传类型 (XEP-0363)
/// - 媒体校验结果
/// - 媒体发送结果
/// - 失败类型枚举
library;

// ===========================================================================
// HTTP 上传类型 (XEP-0363)
// ===========================================================================

/// 上传 slot 信息
///
/// 由服务器返回，包含上传和下载 URL
class UploadSlot {
  final String putUrl;
  final String getUrl;
  final Map<String, String> headers;

  const UploadSlot({
    required this.putUrl,
    required this.getUrl,
    this.headers = const {},
  });

  @override
  String toString() => 'UploadSlot(put: $putUrl, get: $getUrl)';
}

/// 上传进度回调
typedef UploadProgressCallback = void Function(int bytesSent, int totalBytes);

/// HTTP 上传结果
class UploadResult {
  final bool success;
  final String? downloadUrl;
  final String? error;

  const UploadResult._({
    required this.success,
    this.downloadUrl,
    this.error,
  });

  factory UploadResult.success(String downloadUrl) =>
      UploadResult._(success: true, downloadUrl: downloadUrl);

  factory UploadResult.failure(String error) =>
      UploadResult._(success: false, error: error);
}

// ===========================================================================
// 失败类型
// ===========================================================================

/// 上传失败类型
enum UploadFailureType {
  /// 文件不存在（不可重试）
  fileNotFound,

  /// 文件格式不支持（不可重试）
  unsupportedFormat,

  /// 文件内容与扩展名不匹配（不可重试）
  contentMismatch,

  /// 文件过大（不可重试）
  fileTooLarge,

  /// 网络错误（可重试）
  networkError,

  /// 服务器错误（可重试）
  serverError,

  /// 处理失败（可重试）
  processingFailed,

  /// 未知错误
  unknown,
}

/// 判断失败类型是否可重试
extension UploadFailureTypeX on UploadFailureType {
  bool get canRetry {
    switch (this) {
      case UploadFailureType.networkError:
      case UploadFailureType.serverError:
      case UploadFailureType.processingFailed:
        return true;
      case UploadFailureType.fileNotFound:
      case UploadFailureType.unsupportedFormat:
      case UploadFailureType.contentMismatch:
      case UploadFailureType.fileTooLarge:
      case UploadFailureType.unknown:
        return false;
    }
  }
}

// ===========================================================================
// 校验结果
// ===========================================================================

/// 媒体校验结果
class MediaValidationResult {
  final bool isValid;
  final String? errorMessage;
  final UploadFailureType? failureType;

  const MediaValidationResult._({
    required this.isValid,
    this.errorMessage,
    this.failureType,
  });

  factory MediaValidationResult.success() =>
      const MediaValidationResult._(isValid: true);

  factory MediaValidationResult.failure(
    String message,
    UploadFailureType type,
  ) =>
      MediaValidationResult._(
        isValid: false,
        errorMessage: message,
        failureType: type,
      );

  /// 是否可重试
  bool get canRetry => failureType?.canRetry ?? false;
}

// ===========================================================================
// 上传结果
// ===========================================================================

/// 媒体上传结果（队列返回）
class MediaUploadResult {
  final String messageId;
  final String? remoteUrl;
  final String? thumbnailUrl;
  final bool isSuccess;
  final String? errorMessage;
  final UploadFailureType? failureType;

  const MediaUploadResult({
    required this.messageId,
    this.remoteUrl,
    this.thumbnailUrl,
    required this.isSuccess,
    this.errorMessage,
    this.failureType,
  });

  bool get canRetry => failureType?.canRetry ?? false;

  factory MediaUploadResult.success({
    required String messageId,
    required String remoteUrl,
    String? thumbnailUrl,
  }) =>
      MediaUploadResult(
        messageId: messageId,
        remoteUrl: remoteUrl,
        thumbnailUrl: thumbnailUrl,
        isSuccess: true,
      );

  factory MediaUploadResult.failure({
    required String messageId,
    required String errorMessage,
    required UploadFailureType failureType,
  }) =>
      MediaUploadResult(
        messageId: messageId,
        isSuccess: false,
        errorMessage: errorMessage,
        failureType: failureType,
      );
}

// ===========================================================================
// 发送阶段和结果
// ===========================================================================

/// 媒体发送阶段
enum MediaSendStage {
  preparing,
  uploading,
  sendingMessage,
  completed,
  failed,
}

/// 媒体发送结果
class MediaSendResult {
  final bool success;
  final String? messageId;
  final String? error;
  final MediaSendStage? failedStage;
  final UploadFailureType? failureType;

  const MediaSendResult._({
    required this.success,
    this.messageId,
    this.error,
    this.failedStage,
    this.failureType,
  });

  bool get canRetry => failureType?.canRetry ?? false;

  factory MediaSendResult.success(String messageId) =>
      MediaSendResult._(success: true, messageId: messageId);

  factory MediaSendResult.failure(
    String error,
    MediaSendStage stage, {
    UploadFailureType? failureType,
  }) =>
      MediaSendResult._(
        success: false,
        error: error,
        failedStage: stage,
        failureType: failureType,
      );
}

/// 媒体发送进度回调
typedef MediaSendProgressCallback = void Function(
  MediaSendStage stage,
  double progress,
);

// ===========================================================================
// 异常
// ===========================================================================

/// 媒体校验异常
///
/// 发送前校验失败时抛出，调用方应捕获并显示错误
class MediaValidationException implements Exception {
  final String message;
  final UploadFailureType failureType;

  const MediaValidationException(this.message, this.failureType);

  bool get canRetry => failureType.canRetry;

  @override
  String toString() => 'MediaValidationException: $message';
}
