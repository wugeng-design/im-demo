import 'dart:io';

import 'package:flutter/material.dart';

import '../../theme/im_design_tokens.dart';
import 'attachment_models.dart';
import 'attachment_panel.dart';
import 'emoji_panel.dart';

/// 消息输入区域
class MessageInputArea extends StatefulWidget {
  const MessageInputArea({
    super.key,
    required this.onSend,
    this.isSending = false,
    this.onTextChanged,
    this.initialText,
    this.onImageSelected,
    this.onMultipleImagesSelected,
    this.onVideoSelected,
    this.onFileSelected,
  });

  /// 发送消息回调
  final Future<void> Function(String text) onSend;

  /// 是否正在发送
  final bool isSending;

  /// 文本变化回调
  final void Function(String text)? onTextChanged;

  /// 初始文本
  final String? initialText;

  /// 图片选择回调（单张）
  final void Function(File imageFile)? onImageSelected;

  /// 多图选择回调
  final void Function(List<File> imageFiles)? onMultipleImagesSelected;

  /// 视频选择回调
  final void Function(File videoFile)? onVideoSelected;

  /// 文件选择回调
  final void Function(File file)? onFileSelected;

  @override
  State<MessageInputArea> createState() => MessageInputAreaState();
}

class MessageInputAreaState extends State<MessageInputArea> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _showAttachmentPanel = false;
  bool _showEmojiPanel = false;
  bool _hasText = false;

  /// 获取当前文本
  String get currentText => _textController.text;

  /// 设置文本
  void setText(String text) {
    _textController.text = text;
    _focusNode.requestFocus();
  }

  /// 清空文本
  void clear() {
    _textController.clear();
  }

  /// 获取焦点
  void focus() {
    _focusNode.requestFocus();
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialText);
    _textController.addListener(_onTextChanged);
    _focusNode = FocusNode();
    _hasText = _textController.text.isNotEmpty;
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _textController.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
    widget.onTextChanged?.call(_textController.text);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 输入栏
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              top: BorderSide(color: colors.divider, width: 0.5),
            ),
          ),
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: (_showAttachmentPanel || _showEmojiPanel) ? 8 : bottomPadding + 8,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Emoji 按钮
              IconButton(
                icon: Icon(
                  _showEmojiPanel ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined,
                  color: _showEmojiPanel ? colors.primary : colors.textSecondary,
                ),
                onPressed: _toggleEmojiPanel,
              ),
              // 输入框
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 120),
                  decoration: BoxDecoration(
                    color: colors.surfaceVariant,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      hintText: '输入消息...',
                      hintStyle: TextStyle(color: colors.textTertiary),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                    ),
                    onTap: _hidePanels,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 发送按钮 或 附件按钮
              _buildSendOrAttachmentButton(colors),
            ],
          ),
        ),
        // Emoji 面板
        if (_showEmojiPanel)
          EmojiPanel(
            onEmojiSelected: _onEmojiSelected,
          ),
        // 附件面板
        if (_showAttachmentPanel)
          AttachmentPanel(
            onAttachmentSelected: _onAttachmentSelected,
            onMultipleImagesSelected: widget.onMultipleImagesSelected != null
                ? _onMultipleImagesSelected
                : null,
          ),
      ],
    );
  }

  /// 构建发送按钮或附件按钮（根据输入内容切换）
  Widget _buildSendOrAttachmentButton(ImColorScheme colors) {
    if (_hasText) {
      return _buildSendButton(colors);
    }
    return IconButton(
      icon: Icon(
        _showAttachmentPanel ? Icons.close : Icons.add_circle_outline,
        color: _showAttachmentPanel ? colors.primary : colors.textSecondary,
      ),
      onPressed: _toggleAttachmentPanel,
    );
  }

  Widget _buildSendButton(ImColorScheme colors) {
    final canSend = _hasText && !widget.isSending;

    return GestureDetector(
      onTap: canSend ? _onSend : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: canSend ? colors.primary : colors.surfaceVariant,
          shape: BoxShape.circle,
        ),
        child: widget.isSending
            ? Padding(
                padding: const EdgeInsets.all(8),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.onPrimary,
                ),
              )
            : Icon(
                Icons.send,
                size: 18,
                color: canSend ? colors.onPrimary : colors.textDisabled,
              ),
      ),
    );
  }

  void _toggleEmojiPanel() {
    setState(() {
      _showEmojiPanel = !_showEmojiPanel;
      if (_showEmojiPanel) {
        _showAttachmentPanel = false;
        _focusNode.unfocus();
      }
    });
  }

  void _toggleAttachmentPanel() {
    setState(() {
      _showAttachmentPanel = !_showAttachmentPanel;
      if (_showAttachmentPanel) {
        _showEmojiPanel = false;
        _focusNode.unfocus();
      }
    });
  }

  void _hidePanels() {
    if (_showAttachmentPanel || _showEmojiPanel) {
      setState(() {
        _showAttachmentPanel = false;
        _showEmojiPanel = false;
      });
    }
  }

  /// 插入 Emoji 到当前光标位置
  void _onEmojiSelected(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;

    // 如果没有有效选择，在末尾插入
    if (!selection.isValid) {
      _textController.text = '$text$emoji';
      _textController.selection = TextSelection.collapsed(
        offset: _textController.text.length,
      );
      return;
    }

    // 在选择位置插入 emoji（替换选中内容）
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    _textController.text = newText;
    _textController.selection = TextSelection.collapsed(
      offset: selection.start + emoji.length,
    );
  }

  Future<void> _onSend() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    await widget.onSend(text);
    _textController.clear();
  }

  void _onAttachmentSelected(AttachmentType type, File? file) {
    // 关闭面板
    setState(() => _showAttachmentPanel = false);

    if (file == null) return;

    switch (type) {
      case AttachmentType.image:
      case AttachmentType.camera:
        widget.onImageSelected?.call(file);
      case AttachmentType.video:
      case AttachmentType.videoCamera:
        widget.onVideoSelected?.call(file);
      case AttachmentType.file:
        widget.onFileSelected?.call(file);
    }
  }

  void _onMultipleImagesSelected(AttachmentType type, List<File> files) {
    setState(() => _showAttachmentPanel = false);

    if (files.isEmpty) return;

    widget.onMultipleImagesSelected?.call(files);
  }
}
