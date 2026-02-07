import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../theme/im_design_tokens.dart';
import 'attachment_models.dart';
import 'attachment_picker.dart';

/// 附件选择面板
class AttachmentPanel extends StatefulWidget {
  const AttachmentPanel({
    super.key,
    required this.onAttachmentSelected,
    this.onMultipleImagesSelected,
  });

  /// 附件选择回调（单文件）
  final OnAttachmentSelected onAttachmentSelected;

  /// 多图选择回调（相册多选）
  final OnMultipleAttachmentsSelected? onMultipleImagesSelected;

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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          for (int i = 0; i < options.length; i++) ...[
            _buildOptionItem(colors, options[i]),
            if (i < options.length - 1) const SizedBox(width: 24),
          ],
        ],
      ),
    );
  }

  Widget _buildOptionItem(ImColorScheme colors, AttachmentOption option) {
    return GestureDetector(
      onTap: () => _onOptionTap(option.type),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Icon(
                option.icon,
                size: 28,
                color: colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            option.label,
            style: TextStyle(
              fontSize: 12,
              color: colors.textSecondary,
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
}
