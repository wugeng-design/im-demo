import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/im_design_tokens.dart';
import '../../pages/location_picker_page.dart';
import 'attachment_models.dart';
import 'attachment_picker.dart';

/// 附件选择面板
class AttachmentPanel extends StatefulWidget {
  const AttachmentPanel({
    super.key,
    required this.onAttachmentSelected,
    this.onMultipleImagesSelected,
    this.onLocationSelected,
  });

  /// 附件选择回调（单文件）
  final OnAttachmentSelected onAttachmentSelected;

  /// 多图选择回调（相册多选）
  final OnMultipleAttachmentsSelected? onMultipleImagesSelected;

  /// 位置选择回调
  final void Function(Map<String, dynamic> locationData)? onLocationSelected;

  @override
  State<AttachmentPanel> createState() => _AttachmentPanelState();
}

class _AttachmentPanelState extends State<AttachmentPanel> {
  final AttachmentPicker _picker = AttachmentPicker();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);
    final options = AttachmentOption.defaultOptions(
      isMobile: Theme.of(context).platform == TargetPlatform.iOS ||
          Theme.of(context).platform == TargetPlatform.android,
    );
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          top: BorderSide(color: colors.divider, width: 0.5),
        ),
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: bottomPadding + 16,
      ),
      child: Wrap(
        spacing: 24,
        runSpacing: 16,
        children: [
          for (int i = 0; i < options.length; i++)
            _buildOptionItem(colors, options[i]),
        ],
      ),
    );
  }

  // Figma 设计稿常量
  static const double _itemSize = 60.0; // 60x60
  static const double _iconSize = 36.0; // 36x36
  static const double _itemRadius = 8.0; // 8px 圆角
  static const Color _itemBackground = Color(0xFFF6F7FB); // Figma 设计稿背景色
  static const Color _iconColor = Color(0xFF666666); // Figma 设计稿图标颜色
  static const Color _textColor = Color(0xFF666666); // Figma 设计稿文字颜色

  Widget _buildOptionItem(ImColorScheme colors, AttachmentOption option) {
    return GestureDetector(
      onTap: () => _onOptionTap(option.type),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _itemSize,
            height: _itemSize,
            decoration: BoxDecoration(
              color: _itemBackground,
              borderRadius: BorderRadius.circular(_itemRadius),
            ),
            child: Center(
              child: Icon(
                option.icon,
                size: _iconSize,
                color: _iconColor,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            option.label,
            style: const TextStyle(
              fontSize: 12, // Figma: 12px
              color: _textColor,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onOptionTap(AttachmentType type) async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      switch (type) {
        case AttachmentType.image:
          if (widget.onMultipleImagesSelected != null) {
            await _picker.pickMultipleImages(
              maxCount: MultiImageConfig.maxCount,
              onSelected: (files) =>
                  widget.onMultipleImagesSelected!(AttachmentType.image, files),
              onError: _showError,
            );
          } else {
            await _picker.pickImage(
              source: ImageSource.gallery,
              onSelected: (file, type) =>
                  widget.onAttachmentSelected(type, file),
              onError: _showError,
            );
          }
        case AttachmentType.camera:
          await _picker.pickImage(
            source: ImageSource.camera,
            onSelected: (file, type) =>
                widget.onAttachmentSelected(type, file),
            onError: _showError,
          );
        case AttachmentType.video:
          await _picker.pickVideo(
            source: ImageSource.gallery,
            onSelected: (file, type) =>
                widget.onAttachmentSelected(type, file),
            onError: _showError,
          );
        case AttachmentType.videoCamera:
          await _picker.pickVideo(
            source: ImageSource.camera,
            onSelected: (file, type) =>
                widget.onAttachmentSelected(type, file),
            onError: _showError,
          );
        case AttachmentType.file:
          await _picker.pickFile(
            onSelected: (file) =>
                widget.onAttachmentSelected(AttachmentType.file, file),
            onError: _showError,
          );
        case AttachmentType.voice:
          break;
        case AttachmentType.location:
          await _handleLocation();
          break;
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _handleLocation() async {
    // 导航到位置选择页面
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LocationPickerPage(
          onLocationSelected: (locationData) {
            // 调用位置选择回调
            widget.onLocationSelected?.call(locationData);
            
            // 调用附件选择回调（保持兼容）
            widget.onAttachmentSelected(AttachmentType.location, null);
            
            // 显示成功消息
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('位置发送成功: ${locationData['address']}')),
              );
            }
          },
        ),
      ),
    );
  }
  

}
