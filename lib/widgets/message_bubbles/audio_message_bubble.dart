/// 语音消息气泡
///
/// 功能：
/// - 语音条 UI
/// - 接收语音时自动预下载到本地缓存
/// - 下载进度显示
/// - 下载完成后显示声波图标
/// - 播放/暂停按钮
/// - 时长显示
/// - 原地播放（不跳转页面）
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

import '../../providers/audio_playback_provider.dart';
import '../../theme/im_design_tokens.dart';
import '../../theme/message_styles.dart';

/// 语音消息气泡
///
/// 用于显示语音消息，支持：
/// - 自动下载（WiFi 下自动，移动网络需手动触发）
/// - 下载进度显示
/// - 播放/暂停控制
/// - 时长/进度显示
/// - 原地播放，全局只播放一个
class AudioMessageBubble extends ConsumerStatefulWidget {
  const AudioMessageBubble({
    super.key,
    required this.messageId,
    required this.isSentByMe,
    this.audioUrl,
    this.localFilePath,
    this.duration,
    this.cacheKey,
    this.onTap,
  });

  /// 消息 ID
  final String messageId;

  /// 是否是自己发送的
  final bool isSentByMe;

  /// 音频 URL
  final String? audioUrl;

  /// 本地文件路径
  final String? localFilePath;

  /// 音频时长（Duration 对象）
  final Duration? duration;

  /// 缓存 key（用于生成本地缓存路径）
  final String? cacheKey;

  /// 点击回调
  final VoidCallback? onTap;

  @override
  ConsumerState<AudioMessageBubble> createState() => _AudioMessageBubbleState();
}

class _AudioMessageBubbleState extends ConsumerState<AudioMessageBubble> {
  /// 下载状态
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _localCachePath;
  bool _downloadFailed = false;

  /// 获取音频 URL
  String get _audioUrl => widget.audioUrl ?? '';

  /// 是否需要下载
  bool get _needsDownload {
    final url = _audioUrl;
    if (url.isEmpty) return false;
    if (url.startsWith('file://') || url.startsWith('/')) {
      return false;
    }
    return url.startsWith('https://') || url.startsWith('http://');
  }

  /// 是否已有本地文件
  bool get _hasLocalFile {
    if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
      return true;
    }
    return _localCachePath != null;
  }

  @override
  void initState() {
    super.initState();
    _checkAndDownload();
  }

  /// 检查缓存状态并启动下载
  Future<void> _checkAndDownload() async {
    // 发送的消息有本地文件，不需要下载
    if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
      final path = widget.localFilePath!.startsWith('file://')
          ? widget.localFilePath!.substring(7)
          : widget.localFilePath!;
      final file = File(path);
      if (await file.exists()) {
        if (mounted) {
          setState(() {
            _localCachePath = file.path;
          });
        }
        return;
      }
    }

    // 检查是否已有缓存
    final cachedPath = await _getCachedFilePath();
    if (cachedPath != null) {
      if (mounted) {
        setState(() {
          _localCachePath = cachedPath;
        });
      }
      return;
    }

    // 需要下载：WiFi 下自动下载
    if (_needsDownload) {
      final isWifi = await _isWifiConnected();
      if (isWifi) {
        _startDownload();
      }
    }
  }

  /// 获取已缓存的文件路径
  Future<String?> _getCachedFilePath() async {
    final url = _audioUrl;
    if (url.isEmpty) return null;

    final cacheDir = await getTemporaryDirectory();
    final hash = _getCacheHash(url);
    final ext = url.split('.').last.split('?').first;
    final localPath = '${cacheDir.path}/audio_cache/audio_$hash.$ext';
    final file = File(localPath);

    if (await file.exists()) {
      final size = await file.length();
      // 文件大于 1KB 才认为有效
      if (size > 1024) {
        return localPath;
      }
    }
    return null;
  }

  /// 生成缓存 hash
  String _getCacheHash(String url) {
    if (widget.cacheKey != null && widget.cacheKey!.isNotEmpty) {
      return md5.convert(utf8.encode(widget.cacheKey!)).toString();
    }
    return md5.convert(utf8.encode(url)).toString();
  }

  /// 检查是否使用 WiFi 连接
  Future<bool> _isWifiConnected() async {
    try {
      final results = await Connectivity().checkConnectivity();
      return results.contains(ConnectivityResult.wifi) ||
          results.contains(ConnectivityResult.ethernet);
    } catch (e) {
      return true;
    }
  }

  /// 开始下载音频
  Future<void> _startDownload() async {
    if (_isDownloading) return;

    final url = _audioUrl;
    if (url.isEmpty) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadFailed = false;
    });

    try {
      final cacheDir = await getTemporaryDirectory();
      final hash = _getCacheHash(url);
      final ext = url.split('.').last.split('?').first;
      final localPath = '${cacheDir.path}/audio_cache/audio_$hash.$ext';
      final file = File(localPath);

      await file.parent.create(recursive: true);

      debugPrint('[AudioBubble] 开始下载音频: $url');

      // 使用 http 包下载
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('下载失败: HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      int received = 0;
      final bytes = <int>[];

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() {
            _downloadProgress = received / contentLength;
          });
        }
      }

      await file.writeAsBytes(bytes);

      final downloadedSize = await file.length();
      if (downloadedSize < 1024) {
        await file.delete();
        throw Exception('下载的音频文件无效 (${downloadedSize}B)');
      }

      debugPrint('[AudioBubble] 音频下载完成: $localPath (${downloadedSize ~/ 1024}KB)');

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _localCachePath = localPath;
        });
      }
    } catch (e) {
      debugPrint('[AudioBubble] 音频下载失败: $e');
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);
    final playbackState = ref.watch(audioPlaybackProvider);

    // 检查当前消息是否正在播放
    final isThisPlaying = isMessagePlaying(playbackState, widget.messageId);
    final isThisActive = playbackState.currentMessageId == widget.messageId;

    // 显示的时长文本
    final displayDuration = isThisActive
        ? _formatDuration(playbackState.duration - playbackState.position)
        : _formatDuration(widget.duration ?? Duration.zero);

    return GestureDetector(
      onTap: () => _onTap(),
      child: Container(
        constraints: const BoxConstraints(minWidth: 120, maxWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: widget.isSentByMe
              ? colors.messageBubbleSent
              : colors.messageBubbleReceived,
          borderRadius: widget.isSentByMe
              ? MessageStyles.bubbleRadiusSent
              : MessageStyles.bubbleRadiusReceived,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 声波图标/下载进度（发送的在右边，接收的在左边）
            if (!widget.isSentByMe) ...[
              _buildLeftIcon(colors, isThisPlaying),
              const SizedBox(width: 8),
            ],
            // 时长显示
            Text(
              displayDuration,
              style: TextStyle(
                fontSize: 14,
                color: colors.textPrimary,
              ),
            ),
            // 声波图标（发送的在右边）
            if (widget.isSentByMe) ...[
              const SizedBox(width: 8),
              Transform.flip(
                flipX: true,
                child: _buildLeftIcon(colors, isThisPlaying),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建左侧图标（下载进度或声波）
  Widget _buildLeftIcon(ImColorScheme colors, bool isPlaying) {
    // 正在下载：显示进度
    if (_isDownloading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                value: _downloadProgress > 0 ? _downloadProgress : null,
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
          ],
        ),
      );
    }

    // 下载失败：显示重试图标
    if (_downloadFailed && !_hasLocalFile) {
      return SizedBox(
        width: 20,
        height: 20,
        child: Icon(
          Icons.refresh_rounded,
          size: 18,
          color: colors.textSecondary,
        ),
      );
    }

    // 未下载（非 WiFi）：显示下载图标
    if (!_hasLocalFile && _needsDownload) {
      return SizedBox(
        width: 20,
        height: 20,
        child: Icon(
          Icons.download_rounded,
          size: 18,
          color: colors.textSecondary,
        ),
      );
    }

    // 已下载或不需要下载：显示声波
    return _buildSoundWaveIcon(colors, isPlaying);
  }

  /// 声波图标（类似微信的圆弧声波）
  Widget _buildSoundWaveIcon(ImColorScheme colors, bool isPlaying) {
    return SizedBox(
      width: 20,
      height: 20,
      child: isPlaying
          ? _AnimatedSoundWave(color: colors.primary)
          : _StaticSoundWave(color: colors.textSecondary),
    );
  }

  void _onTap() {
    // 触发外部回调
    widget.onTap?.call();

    // 正在下载：不响应点击
    if (_isDownloading) {
      return;
    }

    // 下载失败或未下载：触发下载
    if (_downloadFailed || (!_hasLocalFile && _needsDownload)) {
      _startDownload();
      return;
    }

    // 确定本地文件路径
    String? localFilePath = _localCachePath;
    if (localFilePath == null && widget.localFilePath != null) {
      localFilePath = widget.localFilePath!.startsWith('file://')
          ? widget.localFilePath!.substring(7)
          : widget.localFilePath;
    }

    // 播放音频
    ref.read(audioPlaybackProvider.notifier).togglePlay(
          widget.messageId,
          _audioUrl,
          localFilePath: localFilePath,
        );
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return '0:00';
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// 静态声波图标（3个圆弧）
class _StaticSoundWave extends StatelessWidget {
  const _StaticSoundWave({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(20, 20),
      painter: _SoundWavePainter(color: color, opacity: 1.0),
    );
  }
}

/// 动画声波图标（圆弧逐个闪烁）
class _AnimatedSoundWave extends StatefulWidget {
  const _AnimatedSoundWave({required this.color});

  final Color color;

  @override
  State<_AnimatedSoundWave> createState() => _AnimatedSoundWaveState();
}

class _AnimatedSoundWaveState extends State<_AnimatedSoundWave>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(20, 20),
          painter: _AnimatedSoundWavePainter(
            color: widget.color,
            progress: _controller.value,
          ),
        );
      },
    );
  }
}

/// 声波绘制器（静态）
class _SoundWavePainter extends CustomPainter {
  _SoundWavePainter({required this.color, required this.opacity});

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width * 0.3, size.height / 2);

    // 绘制3个圆弧
    for (int i = 0; i < 3; i++) {
      final radius = 4.0 + i * 5.0;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, -0.8, 1.6, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SoundWavePainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.color != color;
  }
}

/// 声波绘制器（动画 - 逐个显示）
class _AnimatedSoundWavePainter extends CustomPainter {
  _AnimatedSoundWavePainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.3, size.height / 2);

    // 绘制3个圆弧，根据进度逐个显示
    for (int i = 0; i < 3; i++) {
      // 计算每个弧的显示时间段
      final arcStart = i / 3.0;
      final arcEnd = (i + 1) / 3.0;

      double opacity;
      if (progress >= arcStart && progress < arcEnd) {
        // 当前弧正在显示
        opacity = 1.0;
      } else if (progress >= arcEnd) {
        // 已经过了这个弧
        opacity = 0.3;
      } else {
        // 还没到这个弧
        opacity = 0.3;
      }

      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;

      final radius = 4.0 + i * 5.0;
      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, -0.8, 1.6, false, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AnimatedSoundWavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
