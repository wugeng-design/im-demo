/// 语音录制服务
///
/// 功能：
/// - 麦克风权限检查
/// - 开始/停止/取消录音
/// - 录音状态和进度追踪
/// - 录音振幅（用于波形显示）
/// - 录音完成后自动处理（获取时长、生成波形）
library;

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'media/audio_processor.dart';

/// 录音状态
enum RecordingState {
  /// 未开始
  idle,

  /// 准备中
  preparing,

  /// 录音中
  recording,

  /// 已暂停
  paused,

  /// 已完成
  completed,

  /// 已取消
  cancelled,

  /// 错误
  error,
}

/// 录音配置
class RecordingConfig {
  final String? directory;
  final String? fileName;
  final int sampleRate;
  final int bitRate;
  final AudioEncoder encoder;

  const RecordingConfig({
    this.directory,
    this.fileName,
    this.sampleRate = 44100,
    this.bitRate = 64000,
    this.encoder = AudioEncoder.aacLc,
  });

  static const RecordingConfig defaultConfig = RecordingConfig();

  String get extension {
    switch (encoder) {
      case AudioEncoder.aacLc:
      case AudioEncoder.aacEld:
      case AudioEncoder.aacHe:
        return 'm4a';
      case AudioEncoder.wav:
        return 'wav';
      case AudioEncoder.flac:
        return 'flac';
      case AudioEncoder.opus:
        return 'opus';
      case AudioEncoder.amrNb:
      case AudioEncoder.amrWb:
        return 'amr';
      default:
        return 'm4a';
    }
  }
}

/// 录音振幅数据
class AmplitudeData {
  final double current;
  final double max;
  final double min;

  const AmplitudeData({
    this.current = 0.0,
    this.max = 0.0,
    this.min = 0.0,
  });

  /// 归一化值 (0.0 - 1.0)
  double get normalized => max > 0 ? (current / max).clamp(0.0, 1.0) : 0.0;
}

/// 录音结果
class RecordingResult {
  final String? path;
  final String? fileName;
  final int fileSize;
  final Duration duration;
  final List<double>? waveform;
  final String? error;

  const RecordingResult({
    this.path,
    this.fileName,
    this.fileSize = 0,
    this.duration = Duration.zero,
    this.waveform,
    this.error,
  });

  bool get isSuccess => path != null && error == null;

  String get formattedDuration => AudioProcessor.formatDuration(
        duration.inMilliseconds / 1000.0,
      );

  String? get serializedWaveform =>
      waveform != null ? AudioProcessor.serializeWaveform(waveform!) : null;
}

/// 语音录制服务
class VoiceRecorderService {
  final AudioRecorder _recorder = AudioRecorder();
  AmplitudeData _lastAmplitude = const AmplitudeData();
  DateTime? _startTime;
  Timer? _amplitudeTimer;
  StreamController<RecordingState>? _stateController;
  StreamController<AmplitudeData>? _amplitudeController;
  StreamController<Duration>? _durationController;
  String? _currentPath;
  RecordingState _state = RecordingState.idle;

  /// 录音状态流
  Stream<RecordingState> get stateStream =>
      _stateController?.stream ?? const Stream.empty();

  /// 振幅流
  Stream<AmplitudeData> get amplitudeStream =>
      _amplitudeController?.stream ?? const Stream.empty();

  /// 录音时长流
  Stream<Duration> get durationStream =>
      _durationController?.stream ?? const Stream.empty();

  /// 当前状态
  RecordingState get state => _state;

  /// 当前录音时长
  Duration get currentDuration => _startTime != null
      ? DateTime.now().difference(_startTime!)
      : Duration.zero;

  /// 是否已初始化
  bool get _isInitialized =>
      _stateController != null &&
      _amplitudeController != null &&
      _durationController != null;

  /// 初始化
  void _ensureInitialized() {
    if (_isInitialized) return;

    _stateController = StreamController<RecordingState>.broadcast();
    _amplitudeController = StreamController<AmplitudeData>.broadcast();
    _durationController = StreamController<Duration>.broadcast();
  }

  /// 检查麦克风权限
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    debugPrint('[VoiceRecorder] 麦克风权限状态: $status');
    return status.isGranted;
  }

  /// 请求麦克风权限
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    debugPrint('[VoiceRecorder] 请求麦克风权限结果: $status');
    return status.isGranted;
  }

  /// 检查并请求权限
  Future<bool> ensurePermission() async {
    final hasPermission = await checkPermission();
    if (hasPermission) return true;
    return await requestPermission();
  }

  /// 生成录音文件路径
  Future<String> _generateFilePath(RecordingConfig config) async {
    final dir = config.directory ??
        (await getApplicationDocumentsDirectory()).path;
    final fileName = config.fileName ??
        'voice_${DateTime.now().millisecondsSinceEpoch}.${config.extension}';
    return '$dir/$fileName';
  }

  /// 开始录音
  Future<bool> startRecording({
    RecordingConfig config = RecordingConfig.defaultConfig,
  }) async {
    _ensureInitialized();

    if (_state == RecordingState.recording) {
      debugPrint('[VoiceRecorder] 已经在录音中');
      return true;
    }

    _updateState(RecordingState.preparing);

    try {
      final hasPermission = await ensurePermission();
      if (!hasPermission) {
        _updateState(RecordingState.error);
        debugPrint('[VoiceRecorder] 没有麦克风权限');
        return false;
      }

      final path = await _generateFilePath(config);
      debugPrint('[VoiceRecorder] 准备录音到: $path');

      await _recorder.start(
        RecordConfig(
          encoder: config.encoder,
          sampleRate: config.sampleRate,
          bitRate: config.bitRate,
        ),
        path: path,
      );

      _currentPath = path;
      _startTime = DateTime.now();
      _updateState(RecordingState.recording);

      _startAmplitudeMonitoring();

      debugPrint('[VoiceRecorder] 开始录音: $path');
      return true;
    } catch (e) {
      _updateState(RecordingState.error);
      debugPrint('[VoiceRecorder] 开始录音失败: $e');
      return false;
    }
  }

  /// 开始振幅监测
  void _startAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _lastAmplitude = const AmplitudeData();

    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (_) async {
      if (_state != RecordingState.recording) return;

      try {
        final amplitude = await _recorder.getAmplitude();
        final data = AmplitudeData(
          current: amplitude.current,
          max: max(_lastAmplitude.max, amplitude.current),
          min: min(_lastAmplitude.min, amplitude.current),
        );
        _lastAmplitude = data;

        _amplitudeController?.add(data);
        _durationController?.add(currentDuration);
      } catch (e) {
        debugPrint('[VoiceRecorder] 获取振幅失败: $e');
      }
    });
  }

  /// 停止振幅监测
  void _stopAmplitudeMonitoring() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = null;
  }

  /// 暂停录音
  Future<void> pauseRecording() async {
    if (_state != RecordingState.recording) return;

    try {
      await _recorder.pause();
      _stopAmplitudeMonitoring();
      _updateState(RecordingState.paused);
      debugPrint('[VoiceRecorder] 暂停录音');
    } catch (e) {
      debugPrint('[VoiceRecorder] 暂停录音失败: $e');
    }
  }

  /// 恢复录音
  Future<void> resumeRecording() async {
    if (_state != RecordingState.paused) return;

    try {
      await _recorder.resume();
      _startAmplitudeMonitoring();
      _updateState(RecordingState.recording);
      debugPrint('[VoiceRecorder] 恢复录音');
    } catch (e) {
      debugPrint('[VoiceRecorder] 恢复录音失败: $e');
    }
  }

  /// 停止录音并返回结果
  Future<RecordingResult> stopRecording() async {
    if (_state != RecordingState.recording && _state != RecordingState.paused) {
      return const RecordingResult(error: '不在录音状态');
    }

    _stopAmplitudeMonitoring();

    try {
      final path = await _recorder.stop();
      _updateState(RecordingState.completed);

      if (path == null) {
        return const RecordingResult(error: '录音文件为空');
      }

      final file = File(path);
      if (!await file.exists()) {
        return const RecordingResult(error: '录音文件不存在');
      }

      final fileSize = await file.length();
      final duration = currentDuration;

      final durationSeconds = await AudioProcessor.getAudioDuration(path);
      final waveform = await AudioProcessor.generateWaveform(path);

      final result = RecordingResult(
        path: path,
        fileName: path.split('/').last,
        fileSize: fileSize,
        duration: durationSeconds != null
            ? Duration(milliseconds: (durationSeconds * 1000).toInt())
            : duration,
        waveform: waveform,
      );

      debugPrint('[VoiceRecorder] 录音完成: $result');
      return result;
    } catch (e) {
      _updateState(RecordingState.error);
      debugPrint('[VoiceRecorder] 停止录音失败: $e');
      return RecordingResult(error: e.toString());
    }
  }

  /// 取消录音
  Future<void> cancelRecording() async {
    _stopAmplitudeMonitoring();

    try {
      await _recorder.stop();
      _updateState(RecordingState.cancelled);

      if (_currentPath != null) {
        final file = File(_currentPath!);
        if (await file.exists()) {
          await file.delete();
          debugPrint('[VoiceRecorder] 删除临时录音文件: $_currentPath');
        }
      }

      debugPrint('[VoiceRecorder] 取消录音');
    } catch (e) {
      debugPrint('[VoiceRecorder] 取消录音失败: $e');
    }
  }

  /// 更新状态
  void _updateState(RecordingState newState) {
    _state = newState;
    _stateController?.add(newState);
  }

  /// 释放资源
  void dispose() {
    _stopAmplitudeMonitoring();
    _recorder.dispose();
    _stateController?.close();
    _amplitudeController?.close();
    _durationController?.close();
    debugPrint('[VoiceRecorder] 资源已释放');
  }
}

/// 全局录音服务单例
final voiceRecorderServiceProvider = Provider<VoiceRecorderService>((ref) {
  final service = VoiceRecorderService();
  ref.onDispose(() => service.dispose());
  return service;
});
