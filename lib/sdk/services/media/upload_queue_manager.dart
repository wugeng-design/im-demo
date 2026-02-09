/// 上传队列管理器
///
/// 功能：
/// - 控制并发上传数量
/// - 管理上传任务队列
/// - 支持优先级排序
/// - 支持任务取消
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show VoidCallback, debugPrint;

/// 上传队列管理器
class UploadQueueManager {
  /// 默认最大并发数
  static const int defaultMaxConcurrent = 3;

  /// 最大并发上传数量
  final int maxConcurrent;

  /// 任务队列
  final List<_QueuedTask> _queue = [];

  /// 当前活动任务数
  int _activeCount = 0;

  /// 已完成任务数
  int _completedCount = 0;

  /// 失败任务数
  int _failedCount = 0;

  /// 队列状态变化通知
  final StreamController<UploadQueueStatus> _statusController =
      StreamController.broadcast();

  UploadQueueManager({
    this.maxConcurrent = defaultMaxConcurrent,
  });

  /// 队列状态流
  Stream<UploadQueueStatus> get statusStream => _statusController.stream;

  /// 当前队列状态
  UploadQueueStatus get status => UploadQueueStatus(
        queueLength: _queue.length,
        activeCount: _activeCount,
        completedCount: _completedCount,
        failedCount: _failedCount,
        maxConcurrent: maxConcurrent,
      );

  /// 添加上传任务到队列
  ///
  /// [taskId] 任务唯一标识
  /// [uploadTask] 上传任务函数
  /// [priority] 优先级（数字越小优先级越高，默认100）
  /// [onStart] 任务开始时的回调
  /// [onComplete] 任务完成时的回调
  /// [onError] 任务失败时的回调
  Future<T> enqueue<T>({
    required String taskId,
    required Future<T> Function() uploadTask,
    int priority = 100,
    VoidCallback? onStart,
    void Function(T result)? onComplete,
    void Function(Object error)? onError,
  }) async {
    final completer = Completer<T>();

    final queuedTask = _QueuedTask<T>(
      id: taskId,
      task: uploadTask,
      priority: priority,
      completer: completer,
      onStart: onStart,
      onComplete: onComplete,
      onError: onError,
      addedAt: DateTime.now(),
    );

    debugPrint('[UploadQueue] 添加任务 $taskId (优先级: $priority, 队列: ${_queue.length + 1})');

    // 按优先级插入队列
    int insertIndex = _queue.length;
    for (int i = 0; i < _queue.length; i++) {
      if (_queue[i].priority > priority) {
        insertIndex = i;
        break;
      }
    }
    _queue.insert(insertIndex, queuedTask);

    _notifyStatusChange();
    _processQueue();

    return completer.future;
  }

  /// 处理队列
  void _processQueue() {
    while (_activeCount < maxConcurrent && _queue.isNotEmpty) {
      final task = _queue.removeAt(0);
      _executeTask(task);
    }
  }

  /// 执行单个任务
  Future<void> _executeTask<T>(_QueuedTask<T> task) async {
    _activeCount++;
    _notifyStatusChange();

    debugPrint('[UploadQueue] 开始 ${task.id} (活动: $_activeCount/$maxConcurrent)');

    task.onStart?.call();

    try {
      final result = await task.task();
      _completedCount++;

      debugPrint('[UploadQueue] 完成 ${task.id}');
      task.onComplete?.call(result);
      task.completer.complete(result);
    } catch (e) {
      _failedCount++;

      debugPrint('[UploadQueue] 失败 ${task.id}: $e');
      task.onError?.call(e);
      task.completer.completeError(e);
    } finally {
      _activeCount--;
      _notifyStatusChange();
      _processQueue();
    }
  }

  /// 取消队列中的任务（不会取消正在执行的任务）
  bool cancelTask(String taskId) {
    final index = _queue.indexWhere((task) => task.id == taskId);
    if (index != -1) {
      final task = _queue.removeAt(index);
      task.completer.completeError(const UploadQueueCancelledException('任务已取消'));
      debugPrint('[UploadQueue] 取消任务 $taskId');
      _notifyStatusChange();
      return true;
    }
    return false;
  }

  /// 清空队列（不会影响正在执行的任务）
  int clearQueue() {
    final count = _queue.length;
    for (final task in _queue) {
      task.completer.completeError(const UploadQueueCancelledException('队列已清空'));
    }
    _queue.clear();
    debugPrint('[UploadQueue] 清空队列，取消 $count 个任务');
    _notifyStatusChange();
    return count;
  }

  /// 调整任务优先级
  bool adjustPriority(String taskId, int newPriority) {
    final index = _queue.indexWhere((task) => task.id == taskId);
    if (index != -1) {
      final task = _queue.removeAt(index);
      final updatedTask = task.copyWithPriority(newPriority);

      // 重新插入到正确位置
      int insertIndex = _queue.length;
      for (int i = 0; i < _queue.length; i++) {
        if (_queue[i].priority > newPriority) {
          insertIndex = i;
          break;
        }
      }
      _queue.insert(insertIndex, updatedTask);

      debugPrint('[UploadQueue] 调整优先级 $taskId -> $newPriority');
      _notifyStatusChange();
      return true;
    }
    return false;
  }

  /// 获取队列中的任务列表
  List<QueuedTaskInfo> getQueuedTasks() {
    return _queue
        .map((task) => QueuedTaskInfo(
              id: task.id,
              priority: task.priority,
              addedAt: task.addedAt,
            ))
        .toList();
  }

  /// 通知状态变化
  void _notifyStatusChange() {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// 重置统计计数
  void resetStatistics() {
    _completedCount = 0;
    _failedCount = 0;
    debugPrint('[UploadQueue] 统计数据已重置');
    _notifyStatusChange();
  }

  /// 释放资源
  void dispose() {
    clearQueue();
    _statusController.close();
    debugPrint('[UploadQueue] 已释放资源');
  }
}

/// 队列中的上传任务（内部使用）
class _QueuedTask<T> {
  final String id;
  final Future<T> Function() task;
  final int priority;
  final Completer<T> completer;
  final VoidCallback? onStart;
  final void Function(T result)? onComplete;
  final void Function(Object error)? onError;
  final DateTime addedAt;

  _QueuedTask({
    required this.id,
    required this.task,
    required this.priority,
    required this.completer,
    this.onStart,
    this.onComplete,
    this.onError,
    required this.addedAt,
  });

  _QueuedTask<T> copyWithPriority(int newPriority) {
    return _QueuedTask(
      id: id,
      task: task,
      priority: newPriority,
      completer: completer,
      onStart: onStart,
      onComplete: onComplete,
      onError: onError,
      addedAt: addedAt,
    );
  }
}

/// 队列任务信息
class QueuedTaskInfo {
  final String id;
  final int priority;
  final DateTime addedAt;

  const QueuedTaskInfo({
    required this.id,
    required this.priority,
    required this.addedAt,
  });

  @override
  String toString() => 'QueuedTaskInfo($id, priority: $priority)';
}

/// 上传队列状态
class UploadQueueStatus {
  /// 队列中等待的任务数
  final int queueLength;

  /// 当前活动任务数
  final int activeCount;

  /// 已完成任务数
  final int completedCount;

  /// 失败任务数
  final int failedCount;

  /// 最大并发数
  final int maxConcurrent;

  const UploadQueueStatus({
    required this.queueLength,
    required this.activeCount,
    required this.completedCount,
    required this.failedCount,
    required this.maxConcurrent,
  });

  /// 总处理任务数
  int get totalProcessed => completedCount + failedCount;

  /// 成功率
  double get successRate =>
      totalProcessed > 0 ? completedCount / totalProcessed : 0.0;

  /// 是否有活动任务
  bool get hasActiveUploads => activeCount > 0;

  /// 是否队列为空
  bool get isQueueEmpty => queueLength == 0;

  /// 是否完全空闲
  bool get isIdle => queueLength == 0 && activeCount == 0;

  @override
  String toString() =>
      'UploadQueueStatus(queue: $queueLength, active: $activeCount/$maxConcurrent, '
      'done: $completedCount, failed: $failedCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UploadQueueStatus &&
          other.queueLength == queueLength &&
          other.activeCount == activeCount &&
          other.completedCount == completedCount &&
          other.failedCount == failedCount &&
          other.maxConcurrent == maxConcurrent;

  @override
  int get hashCode => Object.hash(
      queueLength, activeCount, completedCount, failedCount, maxConcurrent);
}

/// 上传队列取消异常
class UploadQueueCancelledException implements Exception {
  final String message;
  const UploadQueueCancelledException(this.message);

  @override
  String toString() => 'UploadQueueCancelledException: $message';
}
