import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

import 'attachment_models.dart';

/// 附件选择器
///
/// 封装系统文件选择功能
class AttachmentPicker {
  AttachmentPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// 选择单张图片
  Future<void> pickImage({
    required ImageSource source,
    required void Function(File file, AttachmentType type) onSelected,
    required void Function(String error) onError,
  }) async {
    try {
      final isCamera = source == ImageSource.camera;

      // 拍照时预压缩
      final pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: isCamera ? 85 : 100,
        maxWidth: isCamera ? 1920 : null,
        maxHeight: isCamera ? 1920 : null,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final type = source == ImageSource.camera
            ? AttachmentType.camera
            : AttachmentType.image;
        onSelected(file, type);
      }
    } catch (e) {
      onError('图片选择失败: $e');
    }
  }

  /// 选择多张图片
  Future<void> pickMultipleImages({
    int maxCount = 9,
    required void Function(List<File> files) onSelected,
    required void Function(String error) onError,
  }) async {
    try {
      final pickedFiles = await _picker.pickMultiImage(
        imageQuality: 100,
        limit: maxCount,
      );

      if (pickedFiles.isNotEmpty) {
        final limitedFiles = pickedFiles.take(maxCount).toList();
        final files = limitedFiles.map((xFile) => File(xFile.path)).toList();
        onSelected(files);
      }
    } catch (e) {
      onError('多图选择失败: $e');
    }
  }

  /// 选择视频
  Future<void> pickVideo({
    required ImageSource source,
    Duration maxDuration = const Duration(minutes: 5),
    required void Function(File file, AttachmentType type) onSelected,
    required void Function(String error) onError,
  }) async {
    try {
      final pickedFile = await _picker.pickVideo(
        source: source,
        maxDuration: maxDuration,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final type = source == ImageSource.camera
            ? AttachmentType.videoCamera
            : AttachmentType.video;
        onSelected(file, type);
      }
    } catch (e) {
      onError('视频选择失败: $e');
    }
  }

  /// 选择文件
  Future<void> pickFile({
    required void Function(File file) onSelected,
    required void Function(String error) onError,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final platformFile = result.files.first;
        if (platformFile.path != null) {
          final file = File(platformFile.path!);
          onSelected(file);
        }
      }
    } catch (e) {
      onError('文件选择失败: $e');
    }
  }
}
