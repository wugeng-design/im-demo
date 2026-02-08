import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

/// 图片全屏预览页面
///
/// 功能：
/// - 全屏显示图片
/// - 支持手势缩放（双指捏合）
/// - 支持双击放大
/// - Hero 动画过渡
/// - 优先加载本地文件
class ImagePreviewPage extends StatefulWidget {
  /// 图片 URL
  final String imageUrl;

  /// Hero 动画标签
  final String heroTag;

  /// 文件名（可选）
  final String? fileName;

  /// 本地文件路径（可选，优先使用）
  final String? localFilePath;

  const ImagePreviewPage({
    super.key,
    required this.imageUrl,
    required this.heroTag,
    this.fileName,
    this.localFilePath,
  });

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  /// 是否使用本地文件
  bool _useLocalFile = false;

  /// 本地文件加载失败后回退到远程
  bool _localFileFailed = false;

  @override
  void initState() {
    super.initState();
    _checkLocalFile();
  }

  /// 检查本地文件是否存在
  Future<void> _checkLocalFile() async {
    if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
      final localPath = widget.localFilePath!.startsWith('file://')
          ? widget.localFilePath!.substring(7)
          : widget.localFilePath!;
      final localFile = File(localPath);
      if (await localFile.exists()) {
        if (mounted) {
          setState(() {
            _useLocalFile = true;
          });
        }
        return;
      }
    }
  }

  /// 获取本地文件路径（去除 file:// 前缀）
  String get _localPath {
    final path = widget.localFilePath ?? '';
    return path.startsWith('file://') ? path.substring(7) : path;
  }

  /// 获取图片 Provider（优先本地，失败回退远程）
  ImageProvider get _imageProvider {
    if (_useLocalFile && !_localFileFailed) {
      return FileImage(File(_localPath));
    }
    return CachedNetworkImageProvider(widget.imageUrl);
  }

  /// 本地文件加载失败时回退到远程
  void _onLocalFileError() {
    if (_useLocalFile && !_localFileFailed) {
      setState(() {
        _localFileFailed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Center(
          child: Hero(
            tag: widget.heroTag,
            child: PhotoView(
              imageProvider: _imageProvider,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              initialScale: PhotoViewComputedScale.contained,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              loadingBuilder: (context, event) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      value: event == null
                          ? null
                          : event.cumulativeBytesLoaded /
                              (event.expectedTotalBytes ?? 1),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      event == null
                          ? '加载中...'
                          : '${(event.cumulativeBytesLoaded / 1024).toStringAsFixed(0)} KB',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              errorBuilder: (context, error, stackTrace) {
                // 本地文件加载失败时，尝试回退到远程 URL
                if (_useLocalFile && !_localFileFailed) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _onLocalFileError();
                  });
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.broken_image,
                      size: 60,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '图片加载失败',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setState(() {});
                      },
                      child: const Text('点击重试'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
