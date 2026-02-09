/// 富文本消息气泡
///
/// 功能：
/// - 渲染 @提及（高亮 + 点击跳转）
/// - 渲染链接（高亮 + 点击打开）
/// - 支持已编辑标记
/// - 支持长消息折叠（默认显示 3 行，点击展开）
library;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../theme/im_design_tokens.dart';
import '../../theme/message_styles.dart';
import '../input/mention_utils.dart';

/// 触发折叠的行数阈值
const int _kFoldThresholdLines = 33;

/// 折叠后显示的行数
const int _kCollapsedDisplayLines = 3;

/// 富文本消息气泡
class RichTextMessageBubble extends StatefulWidget {
  const RichTextMessageBubble({
    super.key,
    required this.text,
    required this.isSentByMe,
    required this.timestamp,
    this.isEdited = false,
    this.onMentionTap,
    this.onLongPress,
    this.foldThreshold = _kFoldThresholdLines,
    this.collapsedLines = _kCollapsedDisplayLines,
  });

  /// 消息文本
  final String text;

  /// 是否是自己发送的
  final bool isSentByMe;

  /// 时间戳
  final DateTime timestamp;

  /// 是否已编辑
  final bool isEdited;

  /// @提及点击回调
  final void Function(String mentionedBareJid, String displayName)? onMentionTap;

  /// 长按回调
  final VoidCallback? onLongPress;

  /// 触发折叠的行数阈值
  final int foldThreshold;

  /// 折叠后显示的行数
  final int collapsedLines;

  @override
  State<RichTextMessageBubble> createState() => _RichTextMessageBubbleState();
}

class _RichTextMessageBubbleState extends State<RichTextMessageBubble> {
  /// 是否需要折叠
  bool _needsCollapse = false;

  /// 是否展开显示
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);

    return GestureDetector(
      onLongPress: widget.onLongPress,
      onDoubleTap: _needsCollapse
          ? () => setState(() => _isExpanded = !_isExpanded)
          : null,
      child: Container(
        constraints: MessageStyles.bubbleConstraints,
        padding: MessageStyles.bubblePadding,
        decoration: MessageStyles.bubble(
          widget.isSentByMe
              ? colors.messageBubbleSent
              : colors.messageBubbleReceived,
          radius: widget.isSentByMe
              ? MessageStyles.bubbleRadiusSent
              : MessageStyles.bubbleRadiusReceived,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 消息内容
            _buildContent(context, colors),
            // 时间和状态（微信风格：不显示）
            // const SizedBox(height: 4),
            // _buildFooter(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ImColorScheme colors) {
    final textColor =
        widget.isSentByMe ? Colors.black87 : colors.textPrimary;
    final baseStyle = MessageStyles.bodyText(textColor);

    // 使用 LayoutBuilder 检测是否需要折叠
    return LayoutBuilder(
      builder: (context, constraints) {
        // 创建 TextPainter 计算文本行数
        final textSpan = TextSpan(
          text: widget.text,
          style: baseStyle,
        );
        final textPainter = TextPainter(
          text: textSpan,
          maxLines: widget.foldThreshold + 1,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: constraints.maxWidth);

        _needsCollapse = textPainter.didExceedMaxLines;

        if (!_needsCollapse || _isExpanded) {
          // 不需要折叠或已展开，显示完整内容
          return _buildRichText(widget.text, baseStyle, colors);
        }

        // 需要折叠：显示截断内容 + "更多"
        final moreColor = widget.isSentByMe
            ? colors.primary
            : colors.primary;

        final truncatedText = _truncateText(
          widget.text,
          widget.collapsedLines,
          constraints.maxWidth,
          baseStyle,
        );

        return Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: truncatedText,
                style: baseStyle,
              ),
              TextSpan(
                text: '...',
                style: baseStyle,
              ),
              TextSpan(
                text: '更多',
                style: TextStyle(
                  color: moreColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => setState(() => _isExpanded = true),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 构建富文本（支持 @提及高亮）
  Widget _buildRichText(String text, TextStyle baseStyle, ImColorScheme colors) {
    // 格式化 @提及为显示格式
    final displayText = formatMentionsSimple(text);

    // 检测 @提及并高亮
    final mentionPattern = RegExp(r'@(\S+)');
    final matches = mentionPattern.allMatches(displayText);

    if (matches.isEmpty) {
      return Text(displayText, style: baseStyle);
    }

    // 构建 TextSpan 列表
    final spans = <TextSpan>[];
    var lastEnd = 0;

    for (final match in matches) {
      // 添加普通文本
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: displayText.substring(lastEnd, match.start),
          style: baseStyle,
        ));
      }

      // 添加高亮的 @提及
      spans.add(TextSpan(
        text: match.group(0),
        style: baseStyle.copyWith(
          color: colors.primary,
          fontWeight: FontWeight.w500,
        ),
      ));

      lastEnd = match.end;
    }

    // 添加剩余文本
    if (lastEnd < displayText.length) {
      spans.add(TextSpan(
        text: displayText.substring(lastEnd),
        style: baseStyle,
      ));
    }

    return Text.rich(TextSpan(children: spans));
  }

  /// 截断文本到指定行数
  String _truncateText(
    String text,
    int maxLines,
    double maxWidth,
    TextStyle style,
  ) {
    final lineHeight = style.fontSize! * (style.height ?? 1.2);

    var left = 0;
    var right = text.length;
    var bestOffset = 0;

    while (left < right) {
      final mid = (left + right + 1) ~/ 2;
      final testText = text.substring(0, mid);

      final testPainter = TextPainter(
        text: TextSpan(text: testText, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);

      final textHeight = testPainter.height;
      final numLines = (textHeight / lineHeight).ceil();

      if (numLines <= maxLines) {
        left = mid;
        bestOffset = mid;
      } else {
        right = mid - 1;
      }
    }

    var truncatedText = text.substring(0, bestOffset);
    truncatedText = truncatedText.trimRight();

    return truncatedText;
  }

  /// 构建底部（时间 + 状态 + 已编辑标记）
  Widget _buildFooter(ImColorScheme colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 已编辑标记
        if (widget.isEdited) ...[
          Text(
            '已编辑',
            style: TextStyle(
              color: widget.isSentByMe ? Colors.black45 : colors.textTertiary,
              fontSize: 10,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          _formatTime(widget.timestamp),
          style: TextStyle(
            color: widget.isSentByMe ? Colors.black45 : colors.textTertiary,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
