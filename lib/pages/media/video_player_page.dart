import 'dart:io';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

/// 视频播放页面
///
/// 功能：
/// - 全屏视频播放
/// - 播放控制（播放/暂停、进度条、音量）
/// - 支持本地文件和网络视频
/// - 横屏/竖屏切换
class VideoPlayerPage extends StatefulWidget {
  /// 视频 URL
  final String videoUrl;

  /// 本地文件路径（可选，优先使用）
  final String? localFilePath;

  /// 视频标题（可选）
  final String? title;

  const VideoPlayerPage({
    super.key,
    required this.videoUrl,
    this.localFilePath,
    this.title,
  });

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // 优先使用本地文件
      if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
        final localPath = widget.localFilePath!.startsWith('file://')
            ? widget.localFilePath!.substring(7)
            : widget.localFilePath!;
        final localFile = File(localPath);
        if (await localFile.exists()) {
          _videoController = VideoPlayerController.file(localFile);
        } else {
          _videoController = VideoPlayerController.networkUrl(
            Uri.parse(widget.videoUrl),
          );
        }
      } else {
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
        );
      }

      await _videoController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoController,
        autoPlay: true,
        looping: false,
        showControls: true,
        allowFullScreen: true,
        allowMuting: true,
        showOptions: false,
        placeholder: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.white54,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  errorMessage,
                  style: const TextStyle(color: Colors.white70),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLoading = true;
                      _error = null;
                    });
                    _initializePlayer();
                  },
                  child: const Text('点击重试'),
                ),
              ],
            ),
          );
        },
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = '视频加载失败: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController.dispose();
    // 恢复竖屏
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: widget.title != null
            ? Text(
                widget.title!,
                style: const TextStyle(fontSize: 16),
              )
            : null,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              '正在加载视频...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _initializePlayer();
              },
              child: const Text('点击重试'),
            ),
          ],
        ),
      );
    }

    if (_chewieController == null) {
      return const Center(
        child: Text(
          '播放器初始化失败',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return Center(
      child: Chewie(controller: _chewieController!),
    );
  }
}
