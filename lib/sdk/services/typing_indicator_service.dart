import 'dart:async';

/// 输入状态
enum TypingState {
  /// 空闲
  idle,
  /// 正在输入
  composing,
  /// 暂停输入
  paused,
}

/// 输入状态变更事件
class TypingStateEvent {
  /// 发送者 JID
  final String fromJid;
  /// 会话 ID
  final String conversationId;
  /// 输入状态
  final TypingState state;
  /// 时间戳
  final DateTime timestamp;

  TypingStateEvent({
    required this.fromJid,
    required this.conversationId,
    required this.state,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 输入状态指示器服务
///
/// 管理输入状态的发送和接收
class TypingIndicatorService {
  /// 输入状态流
  final _typingStateController = StreamController<TypingStateEvent>.broadcast();

  /// 当前会话的输入状态（JID -> state）
  final Map<String, TypingStateEvent> _typingStates = {};

  /// 输入超时（超过此时间认为停止输入）
  static const Duration _typingTimeout = Duration(seconds: 5);

  /// 自动清理定时器
  Timer? _cleanupTimer;

  /// 当前用户正在输入的定时器（用于延迟发送 paused）
  Timer? _localTypingTimer;

  /// 当前用户的 JID
  String? currentUserJid;

  TypingIndicatorService() {
    // 定期清理过期的输入状态
    _cleanupTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _cleanupExpiredStates();
    });
  }

  /// 输入状态流
  Stream<TypingStateEvent> get typingStateStream => _typingStateController.stream;

  /// 获取指定会话的输入状态
  TypingStateEvent? getTypingState(String conversationId) {
    return _typingStates[conversationId];
  }

  /// 检查指定会话是否有人正在输入
  bool isTyping(String conversationId) {
    final state = _typingStates[conversationId];
    if (state == null) return false;
    // 检查是否过期
    final elapsed = DateTime.now().difference(state.timestamp);
    return state.state == TypingState.composing && elapsed < _typingTimeout;
  }

  /// 接收到输入状态通知
  void onTypingStateReceived(TypingStateEvent event) {
    // 忽略自己的输入状态
    if (event.fromJid == currentUserJid) return;

    if (event.state == TypingState.composing) {
      _typingStates[event.conversationId] = event;
    } else {
      _typingStates.remove(event.conversationId);
    }

    _typingStateController.add(event);
  }

  /// 本地用户开始输入
  ///
  /// 调用此方法表示用户正在输入，返回需要发送的状态
  TypingState onLocalTyping(String conversationId) {
    // 取消之前的定时器
    _localTypingTimer?.cancel();

    // 设置新的定时器，在停止输入后发送 paused
    _localTypingTimer = Timer(_typingTimeout, () {
      onLocalTypingStopped(conversationId);
    });

    return TypingState.composing;
  }

  /// 本地用户停止输入（发送消息或清空输入框）
  TypingState onLocalTypingStopped(String conversationId) {
    _localTypingTimer?.cancel();
    _localTypingTimer = null;
    return TypingState.paused;
  }

  /// 清理过期的输入状态
  void _cleanupExpiredStates() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _typingStates.entries) {
      final elapsed = now.difference(entry.value.timestamp);
      if (elapsed > _typingTimeout) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      final state = _typingStates.remove(key);
      if (state != null) {
        _typingStateController.add(TypingStateEvent(
          fromJid: state.fromJid,
          conversationId: state.conversationId,
          state: TypingState.idle,
        ));
      }
    }
  }

  /// 释放资源
  void dispose() {
    _cleanupTimer?.cancel();
    _localTypingTimer?.cancel();
    _typingStateController.close();
  }
}
