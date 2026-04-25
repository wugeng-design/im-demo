import 'dart:io';

import 'package:flutter/material.dart';

import '../../sdk/services/voice_recorder_service.dart';
import '../../theme/im_design_tokens.dart';
import 'attachment_models.dart';
import 'attachment_panel.dart';
import 'emoji_panel.dart';
import 'mention_models.dart';
import 'mention_overlay.dart';
import 'mention_utils.dart';
import 'voice_input_button.dart';

enum InputMode {
  text,
  voice,
}

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
    this.onVoiceRecordingComplete,
    this.onLocationSelected,
    this.mentionableMembers,
    this.onVoiceCallSelected,
    this.onVideoCallSelected,
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

  /// 语音录制完成回调
  final void Function(RecordingResult result)? onVoiceRecordingComplete;

  /// 位置选择回调
  final void Function(Map<String, dynamic> locationData)? onLocationSelected;

  /// 可提及的成员列表（群聊时传入）
  final List<MentionableMember>? mentionableMembers;

  /// 语音通话回调
  final void Function()? onVoiceCallSelected;

  /// 视频通话回调
  final void Function()? onVideoCallSelected;

  @override
  State<MessageInputArea> createState() => MessageInputAreaState();
}

class MessageInputAreaState extends State<MessageInputArea> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _showAttachmentPanel = false;
  bool _showEmojiPanel = false;
  bool _hasText = false;
  InputMode _inputMode = InputMode.text;
  RecordingState _recordingState = RecordingState.idle;

  /// @提及检测结果
  MentionDetectionResult _mentionDetection = MentionDetectionResult.empty;

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

  /// 是否正在录音
  bool get isRecording => _recordingState == RecordingState.recording ||
      _recordingState == RecordingState.preparing;

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

    if (widget.mentionableMembers != null && widget.mentionableMembers!.isNotEmpty) {
      final newDetection = detectMention(
        _textController.text,
        _textController.selection.baseOffset,
      );
      if (newDetection.isActive != _mentionDetection.isActive ||
          newDetection.query != _mentionDetection.query) {
        setState(() {
          _mentionDetection = newDetection;
        });
      }
    }
  }

  void _toggleInputMode() {
    setState(() {
      _inputMode = _inputMode == InputMode.text ? InputMode.voice : InputMode.text;
      if (_inputMode == InputMode.text) {
        _focusNode.requestFocus();
      } else {
        _focusNode.unfocus();
        _showAttachmentPanel = false;
        _showEmojiPanel = false;
      }
    });
  }

  void _onRecordingStateChanged(RecordingState state) {
    setState(() {
      _recordingState = state;
    });
  }

  void _onRecordingComplete(RecordingResult result) {
    widget.onVoiceRecordingComplete?.call(result);
  }

  @override
  Widget build(BuildContext context) {
    final colors = ImDesignTokens.colorSchemeOf(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_mentionDetection.isActive && widget.mentionableMembers != null)
          MentionOverlay(
            members: widget.mentionableMembers!,
            query: _mentionDetection.query,
            onMemberSelected: _onMentionMemberSelected,
          ),
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
          child: _inputMode == InputMode.voice
              ? _buildVoiceInputRow(colors)
              : _buildTextInputRow(colors),
        ),
        if (_showEmojiPanel)
          EmojiPanel(
            onEmojiSelected: _onEmojiSelected,
          ),
        if (_showAttachmentPanel)
          AttachmentPanel(
            onAttachmentSelected: _onAttachmentSelected,
            onMultipleImagesSelected: widget.onMultipleImagesSelected != null
                ? _onMultipleImagesSelected
                : null,
            onLocationSelected: (locationData) {
              widget.onLocationSelected?.call(locationData);
            },
            onVoiceCallSelected: widget.onVoiceCallSelected,
            onVideoCallSelected: widget.onVideoCallSelected,
          ),
      ],
    );
  }

  Widget _buildTextInputRow(ImColorScheme colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(
            _inputMode == InputMode.voice ? Icons.keyboard_outlined : Icons.mic_none,
            color: _inputMode == InputMode.voice ? colors.primary : colors.textSecondary,
          ),
          onPressed: _toggleInputMode,
        ),
        IconButton(
          icon: Icon(
            _showEmojiPanel ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined,
            color: _showEmojiPanel ? colors.primary : colors.textSecondary,
          ),
          onPressed: _toggleEmojiPanel,
        ),
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
        _buildSendOrAttachmentButton(colors),
      ],
    );
  }

  Widget _buildVoiceInputRow(ImColorScheme colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        IconButton(
          icon: Icon(
            _inputMode == InputMode.voice ? Icons.keyboard_outlined : Icons.mic_none,
            color: _inputMode == InputMode.voice ? colors.primary : colors.textSecondary,
          ),
          onPressed: _toggleInputMode,
        ),
        Expanded(
          child: VoiceInputButton(
            onRecordingComplete: _onRecordingComplete,
            onRecordingStateChanged: _onRecordingStateChanged,
          ),
        ),
        IconButton(
          icon: Icon(
            _showAttachmentPanel ? Icons.close : Icons.add_circle_outline,
            color: _showAttachmentPanel ? colors.primary : colors.textSecondary,
          ),
          onPressed: _toggleAttachmentPanel,
        ),
      ],
    );
  }

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

  void _onMentionMemberSelected(MentionableMember member) {
    final text = _textController.text;
    final cursorPosition = _textController.selection.baseOffset;

    final newText = replaceMention(
      text,
      _mentionDetection.startIndex,
      cursorPosition,
      member,
    );

    _textController.text = newText;

    final newCursorPosition = _mentionDetection.startIndex +
        '@[${member.nickname}](${member.userBareJid}) '.length;
    _textController.selection = TextSelection.collapsed(offset: newCursorPosition);

    setState(() {
      _mentionDetection = MentionDetectionResult.empty;
    });

    _focusNode.requestFocus();
  }

  void _onEmojiSelected(String emoji) {
    final text = _textController.text;
    final selection = _textController.selection;

    if (!selection.isValid) {
      _textController.text = '$text$emoji';
      _textController.selection = TextSelection.collapsed(
        offset: _textController.text.length,
      );
      return;
    }

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
    setState(() => _showAttachmentPanel = false);

    switch (type) {
      case AttachmentType.image:
      case AttachmentType.camera:
        if (file != null) {
          widget.onImageSelected?.call(file);
        }
        break;
      case AttachmentType.video:
      case AttachmentType.videoCamera:
        if (file != null) {
          widget.onVideoSelected?.call(file);
        }
        break;
      case AttachmentType.file:
        if (file != null) {
          widget.onFileSelected?.call(file);
        }
        break;
      case AttachmentType.voice:
        break;
      case AttachmentType.location:
        final locationData = {
          'latitude': 39.9042,
          'longitude': 116.4074,
          'address': '北京市东城区故宫博物院',
        };
        widget.onLocationSelected?.call(locationData);
        break;
      case AttachmentType.voiceCall:
        widget.onVoiceCallSelected?.call();
        break;
      case AttachmentType.videoCall:
        widget.onVideoCallSelected?.call();
        break;
    }
  }

  void _onMultipleImagesSelected(AttachmentType type, List<File> files) {
    setState(() => _showAttachmentPanel = false);

    if (files.isEmpty) return;

    widget.onMultipleImagesSelected?.call(files);
  }
}
