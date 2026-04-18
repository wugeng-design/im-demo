import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../../theme/im_design_tokens.dart';
import '../../theme/message_styles.dart';
import '../im_avatar.dart';
import '../message_status_widget.dart';
import 'message_bubble.dart';

/// 图片消息气泡
///
/// 功能：
/// - 显示本地/网络图片
/// - 接收图片时自动预下载到本地缓存
/// - WiFi 自动下载策略
/// - 下载进度显示
/// - 动态检测图片尺寸（修复 EXIF 旋转问题）
/// - 上传进度显示
class ImageMessageBubble extends StatefulWidget {
  const ImageMessageBubble({
    super.key,
    required this.isSentByMe,
    this.messageId,
    this.imageUrl,
    this.localFilePath,
    this.width,
    this.height,
    this.status,
    this.uploadProgress,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.showAvatar = false,
    this.autoDownload = true,
    this.onTap,
    this.onLongPress,
    this.onRetry,
    this.onAvatarTap,
  });

  /// 消息 ID（用于缓存和 Hero 动画）
  final String? messageId;

  /// 是否是自己发送的
  final bool isSentByMe;

  /// 图片 URL（网络图片）
  final String? imageUrl;

  /// 本地文件路径
  final String? localFilePath;

  /// 图片宽度
  final double? width;

  /// 图片高度
  final double? height;

  /// 消息状态
  final MessageDisplayStatus? status;

  /// 上传进度 (0.0 - 1.0)
  final double? uploadProgress;

  /// 发送者 ID（用于头像占位符颜色）
  final String? senderId;

  /// 发送者名称
  final String? senderName;

  /// 发送者头像 URL
  final String? senderAvatar;

  /// 是否显示头像
  final bool showAvatar;

  /// 是否自动下载（WiFi 环境）
  final bool autoDownload;

  /// 点击回调
  final VoidCallback? onTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 重试回调
  final VoidCallback? onRetry;

  /// 头像点击回调
  final VoidCallback? onAvatarTap;

  /// 默认尺寸
  static const double _defaultSize = 180.0;

  /// 尺寸缓存
  static final Map<String, Size> _sizeCache = {};

  /// 清除缓存
  static void clearCache() => _sizeCache.clear();

  @override
  State<ImageMessageBubble> createState() => _ImageMessageBubbleState();
}

class _ImageMessageBubbleState extends State<ImageMessageBubble> {
  /// 下载状态
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _localCachePath;
  bool _downloadFailed = false;

  /// 动态检测到的图片尺寸
  Size? _detectedSize;

  /// 获取图片 URL
  String? get _imageUrl => widget.imageUrl;

  /// 是否需要下载
  bool get _needsDownload {
    final url = _imageUrl;
    if (url == null || url.isEmpty) return false;
    if (url.startsWith('file://') || url.startsWith('/')) return false;
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
    _checkAndDetectDimensions();
  }

  /// 检查缓存状态并启动下载
  Future<void> _checkAndDownload() async {
    // 本地文件存在
    if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
      final path = widget.localFilePath!.startsWith('file://')
          ? widget.localFilePath!.substring(7)
          : widget.localFilePath!;
      final file = File(path);
      if (await file.exists()) {
        if (mounted) {
          setState(() => _localCachePath = path);
        }
        return;
      }
    }

    // 检查缓存
    final cachedPath = await _getCachedFilePath();
    if (cachedPath != null) {
      if (mounted) {
        setState(() => _localCachePath = cachedPath);
      }
      return;
    }

    // 需要下载：WiFi 下自动下载
    if (_needsDownload && widget.autoDownload) {
      final isWifi = await _isWifiConnected();
      if (isWifi) {
        _startDownload();
      }
    }
  }

  /// 动态检测图片尺寸
  Future<void> _checkAndDetectDimensions() async {
    await Future.delayed(const Duration(milliseconds: 200));

    String? imagePath = _localCachePath ?? widget.localFilePath;
    if (imagePath == null) return;

    if (imagePath.startsWith('file://')) {
      imagePath = imagePath.substring(7);
    }

    final file = File(imagePath);
    if (!await file.exists()) return;

    try {
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final actualWidth = image.width;
      final actualHeight = image.height;
      image.dispose();

      if (mounted && actualWidth > 0 && actualHeight > 0) {
        final msgWidth = widget.width?.toInt() ?? 0;
        final msgHeight = widget.height?.toInt() ?? 0;
        if (actualWidth != msgWidth || actualHeight != msgHeight) {
          debugPrint('[ImageBubble] 检测到尺寸差异: 消息=${msgWidth}x$msgHeight, 实际=${actualWidth}x$actualHeight');
          setState(() {
            _detectedSize = Size(actualWidth.toDouble(), actualHeight.toDouble());
          });
        }
      }
    } catch (e) {
      debugPrint('[ImageBubble] 动态检测图片尺寸失败: $e');
    }
  }

  /// 获取已缓存的文件路径
  Future<String?> _getCachedFilePath() async {
    final url = _imageUrl;
    if (url == null || url.isEmpty) return null;

    final cacheDir = await getTemporaryDirectory();
    final hash = _getCacheHash(url);
    final ext = _getExtension(url);
    final localPath = '${cacheDir.path}/image_cache/image_$hash.$ext';
    final file = File(localPath);

    if (await file.exists()) {
      final size = await file.length();
      if (size > 1024) return localPath;
    }
    return null;
  }

  /// 生成缓存 hash
  String _getCacheHash(String url) {
    return md5.convert(utf8.encode(url)).toString();
  }

  /// 获取文件扩展名
  String _getExtension(String url) {
    try {
      final ext = url.split('.').last.split('?').first.toLowerCase();
      if (['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext)) {
        return ext;
      }
    } catch (_) {}
    return 'jpg';
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

  /// 开始下载图片
  Future<void> _startDownload() async {
    if (_isDownloading) return;

    final url = _imageUrl;
    if (url == null || url.isEmpty) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadFailed = false;
    });

    try {
      final cacheDir = await getTemporaryDirectory();
      final hash = _getCacheHash(url);
      final ext = _getExtension(url);
      final localPath = '${cacheDir.path}/image_cache/image_$hash.$ext';
      final file = File(localPath);

      await file.parent.create(recursive: true);

      debugPrint('[ImageBubble] 开始下载图片: $url');

      // 使用 http 包下载
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      int received = 0;

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
        throw Exception('下载的图片文件无效 (${downloadedSize}B)');
      }

      debugPrint('[ImageBubble] 图片下载完成: $localPath (${downloadedSize ~/ 1024}KB)');

      if (mounted) {
        setState(() {
          _isDownloading = false;
          _localCachePath = localPath;
        });
        _checkAndDetectDimensions();
      }
    } catch (e) {
      debugPrint('[ImageBubble] 图片下载失败: $e');
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
    final screenWidth = MediaQuery.of(context).size.width;
    final maxWidth = screenWidth * MessageStyles.imageMaxWidthRatio;

    final displaySize = _getDisplaySize(maxWidth);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            widget.isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧头像
          if (widget.showAvatar && !widget.isSentByMe) ...[
            GestureDetector(
              onTap: widget.onAvatarTap,
              child: ImAvatar.small(
                userId: widget.senderId ?? '',
                name: widget.senderName,
                avatarUrl: widget.senderAvatar,
              ),
            ),
            const SizedBox(width: 8),
          ],
          // 发送失败图标（同步自 Light-1-Client 样式）
          if (widget.isSentByMe && widget.status == MessageDisplayStatus.failed)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 8),
              child: MessageFailedIndicator(
                onRetry: widget.onRetry ?? () {},
                size: 20,
              ),
            ),
          // 图片容器
          GestureDetector(
            onTap: _onTap,
            onLongPress: widget.onLongPress,
            child: SizedBox(
              width: displaySize.width,
              height: displaySize.height,
              child: Stack(
                children: [
                  // 图片
                  Hero(
                    tag: 'image_${widget.messageId ?? widget.imageUrl ?? ''}',
                    child: ClipRRect(
                      borderRadius: widget.isSentByMe
                          ? MessageStyles.bubbleRadiusSent
                          : MessageStyles.bubbleRadiusReceived,
                      child: _buildImage(colors, displaySize),
                    ),
                  ),
                  // 下载进度遮罩
                  if (_isDownloading) _buildDownloadOverlay(colors, displaySize),
                  // 下载按钮
                  if (!_hasLocalFile && _needsDownload && !_isDownloading && !_downloadFailed)
                    _buildDownloadButton(colors, displaySize),
                  // 重试按钮
                  if (_downloadFailed && !_hasLocalFile)
                    _buildRetryDownloadButton(colors, displaySize),
                  // 上传进度遮罩
                  if (widget.uploadProgress != null && widget.uploadProgress! < 1.0)
                    _buildUploadOverlay(colors, displaySize),
                  // 发送中指示器
                  if (widget.status == MessageDisplayStatus.sending &&
                      widget.uploadProgress == null)
                    _buildSendingIndicator(colors),
                  // 已发送/已读状态指示器（仅自己发送的消息）
                  if (widget.isSentByMe &&
                      widget.status != null &&
                      widget.status != MessageDisplayStatus.failed &&
                      widget.status != MessageDisplayStatus.sending &&
                      widget.uploadProgress == null)
                    _buildStatusIndicator(colors),
                ],
              ),
            ),
          ),
          // 右侧头像
          if (widget.showAvatar && widget.isSentByMe) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: widget.onAvatarTap,
              child: ImAvatar.small(
                userId: widget.senderId ?? '',
                name: widget.senderName,
                avatarUrl: widget.senderAvatar,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 点击处理
  void _onTap() {
    if (_isDownloading) return;

    if (_downloadFailed || (!_hasLocalFile && _needsDownload)) {
      _startDownload();
      return;
    }

    widget.onTap?.call();
  }

  /// 获取显示尺寸（带缓存）
  Size _getDisplaySize(double maxWidth) {
    final cacheKey = '${widget.messageId ?? widget.imageUrl}_${maxWidth.toInt()}';

    if (_detectedSize != null) {
      final size = _calculateDisplaySizeFromDimensions(
        _detectedSize!.width,
        _detectedSize!.height,
        maxWidth,
      );
      ImageMessageBubble._sizeCache[cacheKey] = size;
      return size;
    }

    return ImageMessageBubble._sizeCache
        .putIfAbsent(cacheKey, () => _calculateDisplaySize(maxWidth));
  }

  /// 计算显示尺寸
  Size _calculateDisplaySize(double maxWidth) {
    final width = widget.width ?? ImageMessageBubble._defaultSize;
    final height = widget.height ?? ImageMessageBubble._defaultSize;
    return _calculateDisplaySizeFromDimensions(width, height, maxWidth);
  }

  /// 根据尺寸计算显示大小
  Size _calculateDisplaySizeFromDimensions(double width, double height, double maxWidth) {
    double scale = 1.0;

    if (width > maxWidth) {
      scale = maxWidth / width;
    }

    final scaledHeight = height * scale;
    if (scaledHeight > MessageStyles.imageMaxHeight) {
      scale = MessageStyles.imageMaxHeight / height;
    }

    final displayWidth =
        (width * scale).clamp(MessageStyles.imageMinSize, maxWidth);
    final displayHeight = (height * scale)
        .clamp(MessageStyles.imageMinSize, MessageStyles.imageMaxHeight);

    return Size(displayWidth, displayHeight);
  }

  /// 构建图片
  Widget _buildImage(ImColorScheme colors, Size displaySize) {
    // 优先使用本地缓存
    if (_localCachePath != null) {
      return _buildLocalFileImage(colors, displaySize, _localCachePath!);
    }

    // 使用传入的本地文件
    if (widget.localFilePath != null && widget.localFilePath!.isNotEmpty) {
      final path = widget.localFilePath!.startsWith('file://')
          ? widget.localFilePath!.substring(7)
          : widget.localFilePath!;
      final file = File(path);
      if (file.existsSync()) {
        return _buildLocalFileImage(colors, displaySize, path);
      }
    }

    // 网络图片
    if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) {
      if (_isDownloading || (_needsDownload && !_hasLocalFile)) {
        return _buildLoadingPlaceholder(colors, displaySize);
      }

      return Image.network(
        widget.imageUrl!,
        width: displaySize.width,
        height: displaySize.height,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildLoadingPlaceholder(colors, displaySize);
        },
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder(colors, displaySize);
        },
      );
    }

    return _buildErrorPlaceholder(colors, displaySize);
  }

  /// 构建本地文件图片
  Widget _buildLocalFileImage(ImColorScheme colors, Size displaySize, String filePath) {
    return Container(
      width: displaySize.width,
      height: displaySize.height,
      color: colors.messageBubbleReceived,
      child: Image.file(
        File(filePath),
        key: ValueKey(filePath),
        width: displaySize.width,
        height: displaySize.height,
        fit: BoxFit.cover,
        cacheWidth: 400,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) {
          return _buildErrorPlaceholder(colors, displaySize);
        },
      ),
    );
  }

  /// 构建下载进度遮罩
  Widget _buildDownloadOverlay(ImColorScheme colors, Size displaySize) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: widget.isSentByMe
              ? MessageStyles.bubbleRadiusSent
              : MessageStyles.bubbleRadiusReceived,
        ),
        child: Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _downloadProgress > 0 ? _downloadProgress : null,
                  strokeWidth: 3,
                  color: Colors.white,
                ),
                Text(
                  '${(_downloadProgress * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建下载按钮
  Widget _buildDownloadButton(ImColorScheme colors, Size displaySize) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: widget.isSentByMe
              ? MessageStyles.bubbleRadiusSent
              : MessageStyles.bubbleRadiusReceived,
        ),
        child: Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.download_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建重试下载按钮
  Widget _buildRetryDownloadButton(ImColorScheme colors, Size displaySize) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: widget.isSentByMe
              ? MessageStyles.bubbleRadiusSent
              : MessageStyles.bubbleRadiusReceived,
        ),
        child: Center(
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.refresh_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      ),
    );
  }

  /// 构建上传进度遮罩
  Widget _buildUploadOverlay(ImColorScheme colors, Size displaySize) {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: widget.isSentByMe
              ? MessageStyles.bubbleRadiusSent
              : MessageStyles.bubbleRadiusReceived,
        ),
        child: Center(
          child: SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: widget.uploadProgress,
                  strokeWidth: 3,
                  color: Colors.white,
                ),
                Text(
                  '${(widget.uploadProgress! * 100).toInt()}%',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建发送中指示器
  Widget _buildSendingIndicator(ImColorScheme colors) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
        ),
        child: const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }

  /// 构建状态指示器（已发送/已送达/已读）
  Widget _buildStatusIndicator(ImColorScheme colors) {
    final IconData icon;
    final Color color;

    switch (widget.status!) {
      case MessageDisplayStatus.sent:
        icon = Icons.check;
        color = Colors.white70;
      case MessageDisplayStatus.delivered:
        icon = Icons.done_all;
        color = Colors.white70;
      case MessageDisplayStatus.read:
        icon = Icons.done_all;
        color = colors.info; // 蓝色表示已读
      default:
        return const SizedBox.shrink();
    }

    return Positioned(
      right: 8,
      bottom: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          size: 14,
          color: color,
        ),
      ),
    );
  }

  /// 构建加载占位符
  Widget _buildLoadingPlaceholder(ImColorScheme colors, Size displaySize) {
    final backgroundColor = widget.isSentByMe
        ? colors.messageBubbleSent
        : colors.messageBubbleReceived;

    return Container(
      width: displaySize.width,
      height: displaySize.height,
      color: backgroundColor,
      child: Center(
        child: Icon(
          Icons.image_outlined,
          size: 48,
          color: colors.textTertiary,
        ),
      ),
    );
  }

  /// 构建错误占位符
  Widget _buildErrorPlaceholder(ImColorScheme colors, Size displaySize) {
    final backgroundColor = widget.isSentByMe
        ? colors.messageBubbleSent
        : colors.messageBubbleReceived;

    return Container(
      width: displaySize.width,
      height: displaySize.height,
      color: backgroundColor,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 32,
            color: colors.textTertiary,
          ),
          const SizedBox(height: 4),
          Text(
            '加载失败',
            style: MessageStyles.systemText(colors.textTertiary),
          ),
        ],
      ),
    );
  }
}
