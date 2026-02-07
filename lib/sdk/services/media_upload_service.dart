import 'dart:io';

import '../models/media.dart';

/// 上传进度回调
typedef UploadProgressCallback = void Function(double progress);

/// 媒体上传结果
class MediaUploadResult {
  const MediaUploadResult({
    required this.success,
    this.remoteUrl,
    this.thumbnailUrl,
    this.error,
  });

  /// 是否成功
  final bool success;

  /// 远程 URL
  final String? remoteUrl;

  /// 缩略图 URL
  final String? thumbnailUrl;

  /// 错误信息
  final String? error;

  /// 成功结果
  factory MediaUploadResult.success({
    required String remoteUrl,
    String? thumbnailUrl,
  }) {
    return MediaUploadResult(
      success: true,
      remoteUrl: remoteUrl,
      thumbnailUrl: thumbnailUrl,
    );
  }

  /// 失败结果
  factory MediaUploadResult.failure(String error) {
    return MediaUploadResult(
      success: false,
      error: error,
    );
  }
}

/// 媒体上传服务接口
///
/// UI 层通过此接口上传媒体文件，不直接依赖具体实现
abstract class MediaUploadService {
  /// 上传图片
  ///
  /// [messageId] 消息 ID（用于跟踪）
  /// [file] 图片文件
  /// [onProgress] 进度回调
  Future<MediaUploadResult> uploadImage({
    required String messageId,
    required File file,
    UploadProgressCallback? onProgress,
  });

  /// 上传视频
  ///
  /// [messageId] 消息 ID
  /// [file] 视频文件
  /// [onProgress] 进度回调
  Future<MediaUploadResult> uploadVideo({
    required String messageId,
    required File file,
    UploadProgressCallback? onProgress,
  });

  /// 上传文件
  ///
  /// [messageId] 消息 ID
  /// [file] 文件
  /// [mimeType] MIME 类型
  /// [onProgress] 进度回调
  Future<MediaUploadResult> uploadFile({
    required String messageId,
    required File file,
    required String mimeType,
    UploadProgressCallback? onProgress,
  });

  /// 取消上传
  ///
  /// [messageId] 消息 ID
  /// 返回是否成功取消
  bool cancelUpload(String messageId);

  /// 重试上传
  ///
  /// [messageId] 消息 ID
  Future<MediaUploadResult> retryUpload(String messageId);

  /// 获取上传状态
  UploadTask? getUploadTask(String messageId);

  /// 上传状态流
  Stream<UploadTask> get uploadTaskStream;
}

/// 模拟媒体上传服务（用于演示）
///
/// 实际项目中应该实现真正的上传逻辑（如 XEP-0363 HTTP Upload）
class MockMediaUploadService implements MediaUploadService {
  final Map<String, UploadTask> _tasks = {};

  @override
  Future<MediaUploadResult> uploadImage({
    required String messageId,
    required File file,
    UploadProgressCallback? onProgress,
  }) async {
    return _simulateUpload(
      messageId: messageId,
      file: file,
      type: MediaType.image,
      onProgress: onProgress,
    );
  }

  @override
  Future<MediaUploadResult> uploadVideo({
    required String messageId,
    required File file,
    UploadProgressCallback? onProgress,
  }) async {
    return _simulateUpload(
      messageId: messageId,
      file: file,
      type: MediaType.video,
      onProgress: onProgress,
    );
  }

  @override
  Future<MediaUploadResult> uploadFile({
    required String messageId,
    required File file,
    required String mimeType,
    UploadProgressCallback? onProgress,
  }) async {
    return _simulateUpload(
      messageId: messageId,
      file: file,
      type: MediaType.file,
      onProgress: onProgress,
    );
  }

  Future<MediaUploadResult> _simulateUpload({
    required String messageId,
    required File file,
    required MediaType type,
    UploadProgressCallback? onProgress,
  }) async {
    // 创建上传任务
    final task = UploadTask(
      id: messageId,
      messageId: messageId,
      media: MediaMetadata(
        type: type,
        localFilePath: file.path,
        fileName: file.path.split('/').last,
      ),
      status: UploadStatus.uploading,
    );
    _tasks[messageId] = task;

    // 模拟上传进度
    for (var i = 0; i <= 10; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      final progress = i / 10.0;
      _tasks[messageId] = task.copyWith(progress: progress);
      onProgress?.call(progress);
    }

    // 模拟上传完成
    _tasks[messageId] = task.copyWith(
      status: UploadStatus.completed,
      progress: 1.0,
    );

    // 返回模拟的 URL（实际项目中应该返回真实的 URL）
    return MediaUploadResult.success(
      remoteUrl: 'https://example.com/uploads/${file.path.split('/').last}',
      thumbnailUrl: type == MediaType.video
          ? 'https://example.com/thumbnails/${file.path.split('/').last}.jpg'
          : null,
    );
  }

  @override
  bool cancelUpload(String messageId) {
    final task = _tasks[messageId];
    if (task != null && task.status == UploadStatus.uploading) {
      _tasks[messageId] = task.copyWith(status: UploadStatus.cancelled);
      return true;
    }
    return false;
  }

  @override
  Future<MediaUploadResult> retryUpload(String messageId) async {
    final task = _tasks[messageId];
    if (task == null) {
      return MediaUploadResult.failure('任务不存在');
    }

    final file = File(task.media.localFilePath!);
    return _simulateUpload(
      messageId: messageId,
      file: file,
      type: task.media.type,
    );
  }

  @override
  UploadTask? getUploadTask(String messageId) => _tasks[messageId];

  @override
  Stream<UploadTask> get uploadTaskStream => Stream.empty();
}
