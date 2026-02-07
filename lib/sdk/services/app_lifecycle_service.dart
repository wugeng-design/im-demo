import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';

/// App 生命周期事件基类
abstract class AppLifecycleEvent {
  const AppLifecycleEvent();
}

/// App 进入后台
class AppPausedEvent extends AppLifecycleEvent {
  const AppPausedEvent();
}

/// App 从后台恢复
class AppResumedEvent extends AppLifecycleEvent {
  /// 后台停留时长
  final Duration backgroundDuration;

  const AppResumedEvent({this.backgroundDuration = Duration.zero});
}

/// App 即将退出
class AppDetachingEvent extends AppLifecycleEvent {
  const AppDetachingEvent();
}

/// 网络恢复
class NetworkRestoredEvent extends AppLifecycleEvent {
  const NetworkRestoredEvent();
}

/// 网络断开
class NetworkLostEvent extends AppLifecycleEvent {
  const NetworkLostEvent();
}

/// App 生命周期服务
///
/// 监听：
/// - App 前后台切换
/// - 网络状态变化
///
/// 使用方式：
/// ```dart
/// final service = AppLifecycleService();
/// service.start();
///
/// service.events.listen((event) {
///   if (event is AppResumedEvent) {
///     // 处理 App 恢复
///   } else if (event is NetworkRestoredEvent) {
///     // 处理网络恢复
///   }
/// });
/// ```
class AppLifecycleService with WidgetsBindingObserver {
  final _eventController = StreamController<AppLifecycleEvent>.broadcast();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  /// 上次进入后台的时间
  DateTime? _lastPausedTime;

  /// 网络是否曾经断开
  bool _wasDisconnected = false;

  /// 当前网络状态
  bool _hasConnection = true;

  /// 是否已启动
  bool _isStarted = false;

  /// 事件流
  Stream<AppLifecycleEvent> get events => _eventController.stream;

  /// 当前是否有网络
  bool get hasConnection => _hasConnection;

  /// 启动服务
  void start() {
    if (_isStarted) return;
    _isStarted = true;

    // 监听 App 生命周期
    WidgetsBinding.instance.addObserver(this);

    // 监听网络状态
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _onConnectivityChanged,
    );

    // 检查初始网络状态
    _checkInitialConnectivity();

    _log('服务已启动');
  }

  /// 停止服务
  void stop() {
    if (!_isStarted) return;
    _isStarted = false;

    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;

    _log('服务已停止');
  }

  /// 释放资源
  void dispose() {
    stop();
    _eventController.close();
  }

  /// 检查初始网络状态
  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _hasConnection = _hasValidConnection(results);
      _log('初始网络状态: ${_hasConnection ? "已连接" : "未连接"}');
    } catch (e) {
      _log('检查网络状态失败: $e');
    }
  }

  /// 网络状态变化回调
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final hasConnection = _hasValidConnection(results);

    _log('网络状态变化: ${hasConnection ? "已连接" : "未连接"}');

    if (!hasConnection) {
      _hasConnection = false;
      _wasDisconnected = true;
      _eventController.add(const NetworkLostEvent());
      return;
    }

    _hasConnection = true;

    // 只有之前断开过才发送恢复事件
    if (_wasDisconnected) {
      _wasDisconnected = false;
      _eventController.add(const NetworkRestoredEvent());
    }
  }

  /// 检查是否有有效网络连接
  bool _hasValidConnection(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        _handleAppPaused();

      case AppLifecycleState.resumed:
        _handleAppResumed();

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _handleAppDetaching();
    }
  }

  void _handleAppPaused() {
    _lastPausedTime = DateTime.now();
    _log('App 进入后台');
    _eventController.add(const AppPausedEvent());
  }

  void _handleAppResumed() {
    Duration backgroundDuration = Duration.zero;
    if (_lastPausedTime != null) {
      backgroundDuration = DateTime.now().difference(_lastPausedTime!);
      _log('App 从后台恢复，后台时长: ${backgroundDuration.inSeconds} 秒');
    } else {
      _log('App 恢复（首次或无后台时间）');
    }
    _lastPausedTime = null;
    _eventController.add(AppResumedEvent(backgroundDuration: backgroundDuration));
  }

  void _handleAppDetaching() {
    _log('App 即将退出');
    _eventController.add(const AppDetachingEvent());
  }

  void _log(String message) {
    print('[AppLifecycleService] $message');
  }
}
