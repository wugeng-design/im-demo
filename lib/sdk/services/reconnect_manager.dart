import 'dart:async';
import 'dart:math';

/// 断线原因
enum DisconnectReason {
  /// 用户手动断开
  manual,

  /// 认证失败
  authenticationFailed,

  /// 网络错误
  networkError,

  /// 服务器错误
  serverError,

  /// App 从后台恢复
  appResumed,

  /// 账号在其他地方登录（被踢）
  conflict,

  /// 未知原因
  unknown,
}

/// 重连状态
enum ReconnectState {
  /// 空闲（未在重连）
  idle,

  /// 等待重连
  waiting,

  /// 正在重连
  reconnecting,

  /// 重连成功
  success,

  /// 达到最大重连次数
  maxAttemptsReached,
}

/// 重连状态变化回调
typedef ReconnectStateCallback = void Function(
  ReconnectState state,
  int attempt,
  int maxAttempts,
  Duration? nextRetryIn,
);

/// 重连管理器
///
/// 实现指数退避重连策略（RFC 6120 兼容）
///
/// 特性：
/// - 指数退避：延迟 = 2^n 秒（最大 5 分钟）
/// - 随机抖动：±10% 避免服务器雪崩
/// - 断线原因分类：不同原因采用不同策略
class ReconnectManager {
  /// 重连回调
  final Future<bool> Function() onReconnect;

  /// 状态变化回调
  final ReconnectStateCallback? onStateChange;

  /// 达到最大重连次数回调
  final VoidCallback? onMaxAttemptsReached;

  /// 基础延迟（秒）
  final int baseDelaySec;

  /// 最大延迟（秒）
  final int maxDelaySec;

  /// 最大重连次数
  final int maxAttempts;

  /// 当前重连次数
  int _reconnectAttempts = 0;

  /// 是否手动断开（阻止自动重连）
  bool _isManuallyDisconnected = false;

  /// 重连定时器
  Timer? _reconnectTimer;

  /// 当前状态
  ReconnectState _state = ReconnectState.idle;

  /// 随机数生成器
  final _random = Random();

  ReconnectManager({
    required this.onReconnect,
    this.onStateChange,
    this.onMaxAttemptsReached,
    this.baseDelaySec = 2,
    this.maxDelaySec = 300, // 5 分钟
    this.maxAttempts = 10,
  });

  /// 当前状态
  ReconnectState get state => _state;

  /// 当前重连次数
  int get reconnectAttempts => _reconnectAttempts;

  /// 是否手动断开
  bool get isManuallyDisconnected => _isManuallyDisconnected;

  /// 调度重连
  ///
  /// 根据断线原因决定是否重连以及重连策略
  void scheduleReconnect({DisconnectReason reason = DisconnectReason.unknown}) {
    // 手动断开：不重连
    if (_isManuallyDisconnected) {
      _log('手动断开状态，跳过重连');
      return;
    }

    // 根据原因决定策略
    switch (reason) {
      case DisconnectReason.manual:
        _log('用户手动断开，不重连');
        _isManuallyDisconnected = true;
        return;

      case DisconnectReason.authenticationFailed:
        _log('认证失败，不重连（需要用户处理）');
        return;

      case DisconnectReason.conflict:
        _log('账号冲突（被踢），不重连（防止循环）');
        _isManuallyDisconnected = true;
        return;

      case DisconnectReason.appResumed:
        _log('App 恢复，立即重连');
        _reconnectAttempts = 0;
        _doReconnect();
        return;

      case DisconnectReason.networkError:
      case DisconnectReason.serverError:
      case DisconnectReason.unknown:
        // 继续执行指数退避重连
        break;
    }

    // 检查是否达到最大重连次数
    _reconnectAttempts++;
    if (_reconnectAttempts > maxAttempts) {
      _log('达到最大重连次数 ($maxAttempts)');
      _updateState(ReconnectState.maxAttemptsReached);
      onMaxAttemptsReached?.call();
      return;
    }

    // 计算延迟（指数退避）
    final baseDelay = baseDelaySec * pow(2, _reconnectAttempts - 1);
    final adjustedBase = reason == DisconnectReason.serverError
        ? baseDelay * 2 // 服务器错误延迟翻倍
        : baseDelay;
    final cappedDelay = min(adjustedBase.toDouble(), maxDelaySec.toDouble());

    // 添加抖动（±10%）
    final jitter = (_random.nextDouble() - 0.5) * 0.2;
    final finalDelay = Duration(
      milliseconds: (cappedDelay * 1000 * (1 + jitter)).toInt(),
    );

    _log('调度重连 #$_reconnectAttempts，延迟 ${finalDelay.inSeconds} 秒');
    _updateState(ReconnectState.waiting, nextRetryIn: finalDelay);

    // 取消之前的定时器
    _reconnectTimer?.cancel();

    // 设置新定时器
    _reconnectTimer = Timer(finalDelay, _doReconnect);
  }

  /// 执行重连
  Future<void> _doReconnect() async {
    _updateState(ReconnectState.reconnecting);
    _log('开始重连...');

    try {
      final success = await onReconnect();
      if (success) {
        _log('重连成功');
        markConnectionSuccess();
      } else {
        _log('重连失败，继续调度');
        scheduleReconnect(reason: DisconnectReason.networkError);
      }
    } catch (e) {
      _log('重连异常: $e');
      scheduleReconnect(reason: DisconnectReason.networkError);
    }
  }

  /// 标记连接成功（重置状态）
  void markConnectionSuccess() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _isManuallyDisconnected = false;
    _updateState(ReconnectState.success);
    // 短暂延迟后重置为 idle
    Future.delayed(const Duration(milliseconds: 100), () {
      _updateState(ReconnectState.idle);
    });
  }

  /// 标记手动断开
  void markManualDisconnect() {
    _isManuallyDisconnected = true;
    cancel();
  }

  /// 重置手动断开状态（允许再次自动重连）
  void resetManualDisconnect() {
    _isManuallyDisconnected = false;
    _reconnectAttempts = 0;
  }

  /// 取消重连
  void cancel() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    _updateState(ReconnectState.idle);
  }

  /// 释放资源
  void dispose() {
    cancel();
  }

  void _updateState(ReconnectState newState, {Duration? nextRetryIn}) {
    _state = newState;
    onStateChange?.call(
      _state,
      _reconnectAttempts,
      maxAttempts,
      nextRetryIn,
    );
  }

  void _log(String message) {
    print('[ReconnectManager] $message');
  }
}

typedef VoidCallback = void Function();
