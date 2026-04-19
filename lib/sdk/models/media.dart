/// 媒体类型
enum MediaType {
  /// 图片
  image,

  /// 视频
  video,

  /// 文件
  file,

  /// 音频
  audio,
}

/// 媒体元数据
class MediaMetadata {
  const MediaMetadata({
    required this.type,
    this.localFilePath,
    this.remoteUrl,
    this.thumbnailUrl,
    this.fileName,
    this.mimeType,
    this.fileSize,
    this.width,
    this.height,
    this.duration,
  });

  /// 媒体类型
  final MediaType type;

  /// 本地文件路径
  final String? localFilePath;

  /// 远程 URL
  final String? remoteUrl;

  /// 缩略图 URL
  final String? thumbnailUrl;

  /// 文件名
  final String? fileName;

  /// MIME 类型
  final String? mimeType;

  /// 文件大小（字节）
  final int? fileSize;

  /// 宽度（图片/视频）
  final int? width;

  /// 高度（图片/视频）
  final int? height;

  /// 时长（视频，秒）
  final int? duration;

  /// 是否有本地文件
  bool get hasLocalFile =>
      localFilePath != null && localFilePath!.isNotEmpty;

  /// 是否有远程 URL
  bool get hasRemoteUrl =>
      remoteUrl != null && remoteUrl!.isNotEmpty;

  /// 复制并修改
  MediaMetadata copyWith({
    MediaType? type,
    String? localFilePath,
    String? remoteUrl,
    String? thumbnailUrl,
    String? fileName,
    String? mimeType,
    int? fileSize,
    int? width,
    int? height,
    int? duration,
  }) {
    return MediaMetadata(
      type: type ?? this.type,
      localFilePath: localFilePath ?? this.localFilePath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileName: fileName ?? this.fileName,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      width: width ?? this.width,
      height: height ?? this.height,
      duration: duration ?? this.duration,
    );
  }

  /// 从 JSON 创建
  factory MediaMetadata.fromJson(Map<String, dynamic> json) {
    return MediaMetadata(
      type: MediaType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MediaType.file,
      ),
      localFilePath: json['localFilePath'] as String?,
      remoteUrl: json['remoteUrl'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      fileName: json['fileName'] as String?,
      mimeType: json['mimeType'] as String?,
      fileSize: json['fileSize'] as int?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      duration: json['duration'] as int?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'localFilePath': localFilePath,
      'remoteUrl': remoteUrl,
      'thumbnailUrl': thumbnailUrl,
      'fileName': fileName,
      'mimeType': mimeType,
      'fileSize': fileSize,
      'width': width,
      'height': height,
      'duration': duration,
    };
  }

  @override
  String toString() =>
      'MediaMetadata(type: $type, fileName: $fileName, fileSize: $fileSize)';
}

/// 上传状态
enum UploadStatus {
  /// 待上传
  pending,

  /// 上传中
  uploading,

  /// 上传完成
  completed,

  /// 上传失败
  failed,

  /// 已取消
  cancelled,
}

/// 上传任务
class UploadTask {
  const UploadTask({
    required this.id,
    required this.messageId,
    required this.media,
    this.status = UploadStatus.pending,
    this.progress = 0.0,
    this.error,
  });

  /// 任务 ID
  final String id;

  /// 关联的消息 ID
  final String messageId;

  /// 媒体元数据
  final MediaMetadata media;

  /// 上传状态
  final UploadStatus status;

  /// 上传进度 (0.0 - 1.0)
  final double progress;

  /// 错误信息
  final String? error;

  /// 复制并修改
  UploadTask copyWith({
    String? id,
    String? messageId,
    MediaMetadata? media,
    UploadStatus? status,
    double? progress,
    String? error,
  }) {
    return UploadTask(
      id: id ?? this.id,
      messageId: messageId ?? this.messageId,
      media: media ?? this.media,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}
