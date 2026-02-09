import 'package:flutter/material.dart';

/// 输入面板类型
enum InputPanelType {
  /// 无面板（仅软键盘或都不显示）
  none,

  /// Emoji 面板
  emoji,

  /// 附件选择面板（图片、视频、文件等）
  attachment,
}

/// 键盘管理器
///
/// 管理软键盘和扩展面板的互斥显示
///
/// 使用示例：
/// ```dart
/// class _InputWidgetState extends State<InputWidget> {
///   late final KeyboardManager _keyboardManager;
///   late final FocusNode _focusNode;
///
///   @override
///   void initState() {
///     super.initState();
///     _keyboardManager = KeyboardManager();
///     _focusNode = FocusNode();
///     _keyboardManager.setFocusNode(_focusNode);
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     return ListenableBuilder(
///       listenable: _keyboardManager,
///       builder: (context, _) {
///         return Column(
///           children: [
///             TextField(focusNode: _focusNode, ...),
///             IconButton(
///               icon: Icon(Icons.emoji_emotions),
///               onPressed: () => _keyboardManager.togglePanel(InputPanelType.emoji),
///             ),
///             if (_keyboardManager.currentPanel == InputPanelType.emoji)
///               EmojiPanel(...),
///           ],
///         );
///       },
///     );
///   }
/// }
/// ```
class KeyboardManager extends ChangeNotifier {
  KeyboardManager();

  /// 当前显示的面板类型
  InputPanelType _currentPanel = InputPanelType.none;

  /// 输入框的 FocusNode
  FocusNode? _focusNode;

  /// 记录的键盘高度（用于面板高度适配）
  double _keyboardHeight = 0;

  /// 默认面板高度
  static const double defaultPanelHeight = 250;

  /// 是否正在切换面板
  bool _isSwitching = false;

  /// 当前显示的面板类型
  InputPanelType get currentPanel => _currentPanel;

  /// 是否显示 Emoji 面板
  bool get isEmojiPanelVisible => _currentPanel == InputPanelType.emoji;

  /// 是否显示附件面板
  bool get isAttachmentPanelVisible => _currentPanel == InputPanelType.attachment;

  /// 是否有面板显示
  bool get isPanelVisible => _currentPanel != InputPanelType.none;

  /// 获取面板高度
  double get panelHeight =>
      _keyboardHeight > 0 ? _keyboardHeight : defaultPanelHeight;

  /// 是否正在切换
  bool get isSwitching => _isSwitching;

  /// 设置 FocusNode
  void setFocusNode(FocusNode focusNode) {
    _focusNode = focusNode;
  }

  /// 更新键盘高度
  void updateKeyboardHeight(double height) {
    if (height > 0 && height != _keyboardHeight) {
      _keyboardHeight = height;
    }
  }

  /// 切换面板
  Future<void> togglePanel(InputPanelType panelType) async {
    if (_isSwitching) return;
    _isSwitching = true;

    try {
      if (_currentPanel == panelType) {
        // 当前显示的是该面板 → 关闭面板，显示键盘
        await _showKeyboard();
      } else if (_currentPanel != InputPanelType.none) {
        // 当前显示的是其他面板 → 直接切换
        _currentPanel = panelType;
        notifyListeners();
      } else {
        // 当前无面板（键盘显示中）→ 收起键盘，显示面板
        await _hideKeyboardAndShowPanel(panelType);
      }
    } finally {
      _isSwitching = false;
    }
  }

  /// 显示键盘，隐藏面板
  Future<void> showKeyboard() async {
    if (_isSwitching) return;
    _isSwitching = true;

    try {
      await _showKeyboard();
    } finally {
      _isSwitching = false;
    }
  }

  /// 隐藏所有（键盘和面板）
  Future<void> hideAll() async {
    if (_isSwitching) return;
    _isSwitching = true;

    try {
      _currentPanel = InputPanelType.none;
      _focusNode?.unfocus();
      notifyListeners();
    } finally {
      _isSwitching = false;
    }
  }

  Future<void> _showKeyboard() async {
    _currentPanel = InputPanelType.none;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 50));
    _focusNode?.requestFocus();
  }

  Future<void> _hideKeyboardAndShowPanel(InputPanelType panelType) async {
    _focusNode?.unfocus();
    await Future.delayed(const Duration(milliseconds: 100));
    _currentPanel = panelType;
    notifyListeners();
  }
}
