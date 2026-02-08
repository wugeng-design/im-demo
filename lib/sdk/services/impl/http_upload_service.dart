import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../media_upload_service.dart';
import '../../models/media.dart';

/// ejabberd HTTP 文件上传服务
///
/// 使用 XEP-0363 HTTP File Upload 协议
/// 需要在 ejabberd 配置 mod_http_upload
class HttpUploadService implements MediaUploadService {
  final String uploadBaseUrl;
  final String? authToken;

  final Map<String, UploadTask> _tasks = {};
  final _taskController = StreamController<UploadTask>.broadcast();

  HttpUploadService({
    required this.uploadBaseUrl,
    this.authToken,
  });

  @override
  Future<MediaUploadResult> uploadImage({
    required String messageId,
    required File file,
    UploadProgressCallback? onProgress,
  }) async {
    return _uploadFile(
      messageId: messageId,
      file: file,
      type: MediaType.image,
      mimeType: _getMimeType(file.path),
      onProgress: onProgress,
    );
  }

  @override
  Future<MediaUploadResult> uploadVideo({
    required String messageId,
    required File file,
    UploadProgressCallback? onProgress,
  }) async {
    return _uploadFile(
      messageId: messageId,
      file: file,
      type: MediaType.video,
      mimeType: _getMimeType(file.path),
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
    return _uploadFile(
      messageId: messageId,
      file: file,
      type: MediaType.file,
      mimeType: mimeType,
      onProgress: onProgress,
    );
  }

  Future<MediaUploadResult> _uploadFile({
    required String messageId,
    required File file,
    required MediaType type,
    required String mimeType,
    UploadProgressCallback? onProgress,
  }) async {
    final fileName = file.path.split('/').last;

    // 创建上传任务
    final task = UploadTask(
      id: messageId,
      messageId: messageId,
      media: MediaMetadata(
        type: type,
        localFilePath: file.path,
        fileName: fileName,
        mimeType: mimeType,
        fileSize: await file.length(),
      ),
      status: UploadStatus.uploading,
    );
    _tasks[messageId] = task;
    _taskController.add(task);

    try {
      // 生成唯一文件名
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final uniqueFileName = '${timestamp}_$fileName';

      // 构建上传 URL
      final uploadUrl = '$uploadBaseUrl/$uniqueFileName';

      print('[HttpUpload] Uploading to: $uploadUrl');

      // 读取文件内容
      final fileBytes = await file.readAsBytes();
      final fileLength = fileBytes.length;

      // 发送 PUT 请求上传文件
      final request = http.Request('PUT', Uri.parse(uploadUrl));
      request.headers['Content-Type'] = mimeType;
      request.headers['Content-Length'] = fileLength.toString();

      if (authToken != null) {
        request.headers['Authorization'] = 'Bearer $authToken';
      }

      request.bodyBytes = fileBytes;

      // 发送请求
      final streamedResponse = await request.send();

      // 模拟进度（HTTP 请求不支持实时进度）
      onProgress?.call(0.5);

      final response = await http.Response.fromStream(streamedResponse);

      print('[HttpUpload] Response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // 上传成功
        final remoteUrl = uploadUrl;

        _tasks[messageId] = task.copyWith(
          status: UploadStatus.completed,
          progress: 1.0,
        );
        _taskController.add(_tasks[messageId]!);

        onProgress?.call(1.0);

        return MediaUploadResult.success(remoteUrl: remoteUrl);
      } else {
        throw Exception('Upload failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      print('[HttpUpload] Error: $e');

      _tasks[messageId] = task.copyWith(
        status: UploadStatus.failed,
      );
      _taskController.add(_tasks[messageId]!);

      return MediaUploadResult.failure('上传失败: $e');
    }
  }

  @override
  bool cancelUpload(String messageId) {
    final task = _tasks[messageId];
    if (task != null && task.status == UploadStatus.uploading) {
      _tasks[messageId] = task.copyWith(status: UploadStatus.cancelled);
      _taskController.add(_tasks[messageId]!);
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
    return _uploadFile(
      messageId: messageId,
      file: file,
      type: task.media.type,
      mimeType: task.media.mimeType ?? 'application/octet-stream',
    );
  }

  @override
  UploadTask? getUploadTask(String messageId) => _tasks[messageId];

  @override
  Stream<UploadTask> get uploadTaskStream => _taskController.stream;

  String _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'mp4' => 'video/mp4',
      'mov' => 'video/quicktime',
      'avi' => 'video/x-msvideo',
      'pdf' => 'application/pdf',
      _ => 'application/octet-stream',
    };
  }

  void dispose() {
    _taskController.close();
  }
}
