import 'dart:io';

/// 头像上传结果
class AvatarUploadResult {
  final bool success;
  final String? avatarUrl;
  final String? error;

  const AvatarUploadResult._({
    required this.success,
    this.avatarUrl,
    this.error,
  });

  factory AvatarUploadResult.success(String avatarUrl) =>
      AvatarUploadResult._(success: true, avatarUrl: avatarUrl);

  factory AvatarUploadResult.failure(String error) =>
      AvatarUploadResult._(success: false, error: error);
}

/// 头像上传配置
class AvatarUploadConfig {
  /// 头像最大尺寸（正方形边长）
  final int maxSize;

  /// 压缩质量 (0-100)
  final int quality;

  /// 最大文件大小（字节）
  final int maxFileSize;

  const AvatarUploadConfig({
    this.maxSize = 512,
    this.quality = 85,
    this.maxFileSize = 500 * 1024, // 500KB
  });

  static const defaultConfig = AvatarUploadConfig();
}

/// 头像上传进度回调
typedef AvatarProgressCallback = void Function(double progress);

/// 头像上传服务接口
///
/// 提供个人头像和群头像的上传功能
/// 使用 XEP-0363 HTTP File Upload 上传图片
/// 然后将 URL 存储到 vCard
abstract class AvatarUploadService {
  /// 上传用户头像
  ///
  /// [imageFile] 图片文件
  /// [onProgress] 进度回调 (0.0 - 1.0)
  ///
  /// 返回上传结果，包含头像 URL
  Future<AvatarUploadResult> uploadUserAvatar({
    required File imageFile,
    AvatarProgressCallback? onProgress,
  });

  /// 上传群头像
  ///
  /// [groupJid] 群 JID (如 room@conference.localhost)
  /// [imageFile] 图片文件
  /// [onProgress] 进度回调
  ///
  /// 返回上传结果，包含头像 URL
  Future<AvatarUploadResult> uploadGroupAvatar({
    required String groupJid,
    required File imageFile,
    AvatarProgressCallback? onProgress,
  });

  /// 获取当前用户头像 URL
  Future<String?> getUserAvatarUrl();

  /// 获取指定用户头像 URL
  ///
  /// [userJid] 用户 JID
  Future<String?> getUserAvatarUrlByJid(String userJid);

  /// 获取群头像 URL
  ///
  /// [groupJid] 群 JID
  Future<String?> getGroupAvatarUrl(String groupJid);
}
