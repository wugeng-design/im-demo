import 'dart:io';

import 'package:flutter/material.dart';

/// 附件类型
enum AttachmentType {
  /// 图片（相册）
  image,

  /// 拍照
  camera,

  /// 视频（相册）
  video,

  /// 录制视频
  videoCamera,

  /// 文件
  file,
}

/// 附件选择回调（单文件）
typedef OnAttachmentSelected = void Function(
  AttachmentType type,
  File? file,
);

/// 附件选择回调（多文件）
typedef OnMultipleAttachmentsSelected = void Function(
  AttachmentType type,
  List<File> files,
);

/// 多图选择限制
class MultiImageConfig {
  const MultiImageConfig._();

  /// 最大选择数量
  static const int maxCount = 9;
}

/// 附件选项配置
class AttachmentOption {
  const AttachmentOption({
    required this.type,
    required this.icon,
    required this.label,
  });

  final AttachmentType type;
  final IconData icon;
  final String label;

  /// 默认选项列表
  static List<AttachmentOption> defaultOptions({bool isMobile = true}) {
    return [
      const AttachmentOption(
        type: AttachmentType.image,
        icon: Icons.photo_library,
        label: '相册',
      ),
      if (isMobile)
        const AttachmentOption(
          type: AttachmentType.camera,
          icon: Icons.camera_alt,
          label: '拍照',
        ),
      const AttachmentOption(
        type: AttachmentType.video,
        icon: Icons.videocam,
        label: '视频',
      ),
      const AttachmentOption(
        type: AttachmentType.file,
        icon: Icons.insert_drive_file,
        label: '文件',
      ),
    ];
  }
}
