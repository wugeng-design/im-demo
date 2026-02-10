import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../avatar_upload_service.dart';
import 'xep0363_upload_service.dart';
import 'ejabberd_api_client.dart';
import '../media/image_processor.dart';

/// 头像上传服务实现
///
/// 使用 XEP-0363 HTTP File Upload 上传头像图片
/// 然后将 URL 存储到 vCard（个人头像）或群配置（群头像）
class AvatarUploadServiceImpl implements AvatarUploadService {
  final Xep0363UploadService _uploadService;
  final EjabberdApiClient _apiClient;
  final ImageProcessor _imageProcessor;
  final String _currentUser;
  final String _domain;

  AvatarUploadServiceImpl({
    required Xep0363UploadService uploadService,
    required EjabberdApiClient apiClient,
    required String currentUser,
    required String domain,
    ImageProcessor? imageProcessor,
  })  : _uploadService = uploadService,
        _apiClient = apiClient,
        _imageProcessor = imageProcessor ?? ImageProcessor(),
        _currentUser = currentUser,
        _domain = domain;

  @override
  Future<AvatarUploadResult> uploadUserAvatar({
    required File imageFile,
    AvatarProgressCallback? onProgress,
  }) async {
    try {
      debugPrint('[AvatarUpload] 开始上传用户头像: ${imageFile.path}');

      // 1. 处理图片 (裁剪+压缩) - 0-20%
      onProgress?.call(0.05);
      final processedData = await _processAvatarImage(imageFile);
      if (processedData == null) {
        return AvatarUploadResult.failure('图片处理失败');
      }
      onProgress?.call(0.2);

      // 2. 保存到临时文件
      final tempFile = await _imageProcessor.saveToTempFile(
        Uint8List.fromList(processedData),
        'avatar_$_currentUser.jpg',
      );
      if (tempFile == null) {
        return AvatarUploadResult.failure('保存临时文件失败');
      }

      // 3. 上传到服务器 (20-80%)
      final messageId = 'avatar_${_currentUser}_${DateTime.now().millisecondsSinceEpoch}';
      final uploadResult = await _uploadService.uploadImage(
        messageId: messageId,
        file: tempFile,
        onProgress: (p) => onProgress?.call(0.2 + p * 0.6),
      );

      if (!uploadResult.success || uploadResult.remoteUrl == null) {
        return AvatarUploadResult.failure(uploadResult.error ?? '上传失败');
      }

      debugPrint('[AvatarUpload] 图片上传成功: ${uploadResult.remoteUrl}');

      // 4. 更新 vCard (80-95%)
      onProgress?.call(0.8);
      try {
        await _apiClient.setUserAvatarUrl(
          _currentUser,
          _domain,
          uploadResult.remoteUrl!,
        );
        debugPrint('[AvatarUpload] vCard 更新成功');
      } catch (e) {
        debugPrint('[AvatarUpload] vCard 更新失败: $e');
        // vCard 更新失败不影响整体结果，图片已上传成功
      }

      // 5. 清理临时文件
      _cleanupTempFile(tempFile);

      onProgress?.call(1.0);
      return AvatarUploadResult.success(uploadResult.remoteUrl!);
    } catch (e) {
      debugPrint('[AvatarUpload] 上传失败: $e');
      return AvatarUploadResult.failure('上传失败: $e');
    }
  }

  @override
  Future<AvatarUploadResult> uploadGroupAvatar({
    required String groupJid,
    required File imageFile,
    AvatarProgressCallback? onProgress,
  }) async {
    try {
      debugPrint('[AvatarUpload] 开始上传群头像: $groupJid');

      // 1. 处理图片
      onProgress?.call(0.05);
      final processedData = await _processAvatarImage(imageFile);
      if (processedData == null) {
        return AvatarUploadResult.failure('图片处理失败');
      }
      onProgress?.call(0.2);

      // 2. 保存到临时文件
      final roomName = groupJid.split('@').first;
      final tempFile = await _imageProcessor.saveToTempFile(
        Uint8List.fromList(processedData),
        'group_avatar_$roomName.jpg',
      );
      if (tempFile == null) {
        return AvatarUploadResult.failure('保存临时文件失败');
      }

      // 3. 上传到服务器
      final messageId = 'group_avatar_${roomName}_${DateTime.now().millisecondsSinceEpoch}';
      final uploadResult = await _uploadService.uploadImage(
        messageId: messageId,
        file: tempFile,
        onProgress: (p) => onProgress?.call(0.2 + p * 0.6),
      );

      if (!uploadResult.success || uploadResult.remoteUrl == null) {
        return AvatarUploadResult.failure(uploadResult.error ?? '上传失败');
      }

      debugPrint('[AvatarUpload] 群头像上传成功: ${uploadResult.remoteUrl}');

      // 4. 更新群配置
      onProgress?.call(0.8);
      try {
        final mucService = 'conference.$_domain';
        await _apiClient.setRoomAvatar(roomName, mucService, uploadResult.remoteUrl!);
        debugPrint('[AvatarUpload] 群配置更新成功');
      } catch (e) {
        debugPrint('[AvatarUpload] 群配置更新失败: $e');
      }

      // 5. 清理
      _cleanupTempFile(tempFile);

      onProgress?.call(1.0);
      return AvatarUploadResult.success(uploadResult.remoteUrl!);
    } catch (e) {
      debugPrint('[AvatarUpload] 群头像上传失败: $e');
      return AvatarUploadResult.failure('上传失败: $e');
    }
  }

  @override
  Future<String?> getUserAvatarUrl() async {
    return getUserAvatarUrlByJid('$_currentUser@$_domain');
  }

  @override
  Future<String?> getUserAvatarUrlByJid(String userJid) async {
    try {
      final parts = userJid.split('@');
      if (parts.length != 2) return null;

      final user = parts[0];
      final host = parts[1];

      final vcard = await _apiClient.getVcard(user, host);
      if (vcard == null) return null;

      // vCard 返回格式可能是:
      // 1. {PHOTO: {EXTVAL: "url"}}
      // 2. {vcard: [{name: "PHOTO EXTVAL", value: "url"}]}
      if (vcard['PHOTO'] is Map) {
        return vcard['PHOTO']['EXTVAL'] as String?;
      }

      // 尝试从 vcard 数组格式解析
      final vcardList = vcard['vcard'];
      if (vcardList is List) {
        for (final item in vcardList) {
          if (item is Map && item['name'] == 'PHOTO EXTVAL') {
            return item['value'] as String?;
          }
        }
      }

      return null;
    } catch (e) {
      debugPrint('[AvatarUpload] 获取用户头像失败: $e');
      return null;
    }
  }

  @override
  Future<String?> getGroupAvatarUrl(String groupJid) async {
    try {
      final roomName = groupJid.split('@').first;
      final mucService = 'conference.$_domain';
      final options = await _apiClient.getRoomOptions(roomName, mucService);
      return options['vcard_photo'] as String?;
    } catch (e) {
      debugPrint('[AvatarUpload] 获取群头像失败: $e');
      return null;
    }
  }

  /// 处理头像图片（裁剪为正方形 + 压缩）
  Future<List<int>?> _processAvatarImage(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      const config = AvatarUploadConfig.defaultConfig;

      debugPrint('[AvatarUpload] 处理图片: ${bytes.length} bytes');

      // 压缩到正方形尺寸
      var result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: config.maxSize,
        minHeight: config.maxSize,
        quality: config.quality,
        format: CompressFormat.jpeg,
      );

      debugPrint('[AvatarUpload] 第一次压缩: ${result.length} bytes');

      // 如果超过最大文件大小，降低质量重新压缩
      if (result.length > config.maxFileSize) {
        debugPrint('[AvatarUpload] 文件过大，降低质量重新压缩');
        result = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: config.maxSize,
          minHeight: config.maxSize,
          quality: (config.quality * 0.6).toInt(),
          format: CompressFormat.jpeg,
        );
        debugPrint('[AvatarUpload] 第二次压缩: ${result.length} bytes');
      }

      return result;
    } catch (e) {
      debugPrint('[AvatarUpload] 图片处理异常: $e');
      return null;
    }
  }

  /// 清理临时文件
  void _cleanupTempFile(File file) {
    try {
      file.delete();
    } catch (_) {}
  }
}
