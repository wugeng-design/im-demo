/// 上传进度指示器
///
/// 功能：
/// - 环形进度显示
/// - 百分比文本
/// - 取消按钮
library;

import 'package:flutter/material.dart';

import '../../theme/im_design_tokens.dart';

/// 上传进度指示器
class UploadProgressIndicator extends StatelessWidget {
  const UploadProgressIndicator({
    super.key,
    required this.progress,
    this.size = 48,
    this.strokeWidth = 3,
    this.showPercentage = true,
    this.showCancel = true,
    this.onCancel,
    this.backgroundColor,
    this.progressColor,
  });

  /// 进度 (0.0 - 1.0)
  final double progress;

  /// 指示器大小
  final double size;

  /// 进度条宽度
  final double strokeWidth;

  /// 是否显示百分比
  final bool showPercentage;

  /// 是否显示取消按钮
  final bool showCancel;

  /// 取消回调
  final VoidCallback? onCancel;

  /// 背景颜色
  final Color? backgroundColor;

  /// 进度条颜色
  final Color? progressColor;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);
    final bgColor = backgroundColor ?? Colors.black.withValues(alpha: 0.5);
    final fgColor = progressColor ?? colors.primary;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 背景圆环
          CircularProgressIndicator(
            value: 1.0,
            strokeWidth: strokeWidth,
            color: bgColor.withValues(alpha: 0.3),
          ),
          // 进度圆环
          CircularProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            strokeWidth: strokeWidth,
            color: fgColor,
          ),
          // 中心内容（百分比或取消按钮）
          if (showCancel && onCancel != null)
            GestureDetector(
              onTap: onCancel,
              child: Container(
                width: size - strokeWidth * 4,
                height: size - strokeWidth * 4,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.close,
                  size: size * 0.4,
                  color: Colors.white,
                ),
              ),
            )
          else if (showPercentage)
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: size * 0.25,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }
}

/// 上传进度覆盖层
///
/// 覆盖在图片/视频缩略图上，显示上传进度
class UploadProgressOverlay extends StatelessWidget {
  const UploadProgressOverlay({
    super.key,
    required this.progress,
    required this.child,
    this.isUploading = true,
    this.isFailed = false,
    this.onRetry,
    this.onCancel,
  });

  /// 进度 (0.0 - 1.0)
  final double progress;

  /// 子组件（通常是缩略图）
  final Widget child;

  /// 是否正在上传
  final bool isUploading;

  /// 是否失败
  final bool isFailed;

  /// 重试回调
  final VoidCallback? onRetry;

  /// 取消回调
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return Stack(
      children: [
        // 子组件
        child,
        // 半透明覆盖层
        if (isUploading || isFailed)
          Positioned.fill(
            child: Container(
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
        // 进度指示器或失败图标
        if (isUploading)
          Positioned.fill(
            child: Center(
              child: UploadProgressIndicator(
                progress: progress,
                size: 48,
                onCancel: onCancel,
              ),
            ),
          )
        else if (isFailed)
          Positioned.fill(
            child: Center(
              child: GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// 线性上传进度条
class UploadProgressBar extends StatelessWidget {
  const UploadProgressBar({
    super.key,
    required this.progress,
    this.height = 4,
    this.backgroundColor,
    this.progressColor,
    this.showPercentage = false,
  });

  /// 进度 (0.0 - 1.0)
  final double progress;

  /// 进度条高度
  final double height;

  /// 背景颜色
  final Color? backgroundColor;

  /// 进度条颜色
  final Color? progressColor;

  /// 是否显示百分比
  final bool showPercentage;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);
    final bgColor = backgroundColor ?? colors.surfaceVariant;
    final fgColor = progressColor ?? colors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showPercentage)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: height,
            backgroundColor: bgColor,
            valueColor: AlwaysStoppedAnimation<Color>(fgColor),
          ),
        ),
      ],
    );
  }
}
