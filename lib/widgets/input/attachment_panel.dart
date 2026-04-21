import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import '../../theme/im_design_tokens.dart';
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
    try {
      // 检查位置权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showError('需要位置权限才能发送位置信息');
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        _showError('位置权限已被永久拒绝，请在设置中开启');
        return;
      }
      
      // 获取当前位置
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // 通过地理编码获取地址信息
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      if (placemarks.isEmpty) {
        _showError('无法获取地址信息');
        return;
      }
      
      Placemark placemark = placemarks[0];
      String address = _formatAddress(placemark);
      
      // 构建位置数据
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'address': address,
      };
      
      // 调用位置选择回调
      widget.onLocationSelected?.call(locationData);
      
      // 调用附件选择回调（保持兼容）
      widget.onAttachmentSelected(AttachmentType.location, null);
      
      // 显示成功消息
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('位置发送成功: $address')),
        );
      }
    } catch (e) {
      _showError('获取位置失败: ${e.toString()}');
    }
  }
  
  String _formatAddress(Placemark placemark) {
    List<String> addressParts = [];
    
    if (placemark.country != null && placemark.country!.isNotEmpty) {
      addressParts.add(placemark.country!);
    }
    if (placemark.administrativeArea != null && placemark.administrativeArea!.isNotEmpty) {
      addressParts.add(placemark.administrativeArea!);
    }
    if (placemark.locality != null && placemark.locality!.isNotEmpty) {
      addressParts.add(placemark.locality!);
    }
    if (placemark.subLocality != null && placemark.subLocality!.isNotEmpty) {
      addressParts.add(placemark.subLocality!);
    }
    if (placemark.street != null && placemark.street!.isNotEmpty) {
      addressParts.add(placemark.street!);
    }
    if (placemark.name != null && placemark.name!.isNotEmpty) {
      addressParts.add(placemark.name!);
    }
    
    return addressParts.join(' ');
  }
}
